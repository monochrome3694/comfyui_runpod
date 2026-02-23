# runpod-handler/handler.py
#
# RunPod serverless handler for ComfyUI image generation.
# When presigned R2 URLs are provided, uploads output directly to R2
# instead of returning base64 — eliminates blob proxying through Workers.
#
# Fallback: If no presigned URLs, returns base64 (backward compat with old Worker).

import runpod
import requests
import json
import base64
import time
from pathlib import Path

try:
    from PIL import Image
    import io
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

COMFY_OUTPUT_DIR = "/comfyui/output"
COMFY_API = "http://127.0.0.1:8188"
POLL_INTERVAL = 2  # seconds
POLL_TIMEOUT_IMAGE = 300  # 5 minutes for images
POLL_TIMEOUT_VIDEO = 1800  # 30 minutes for videos
STARTUP_TIMEOUT = 120  # seconds to wait for ComfyUI to become ready

# Content type map — must match what presigned-urls.ts signs for
CONTENT_TYPES = {
    ".mp4": "video/mp4",
    ".mov": "video/mp4",  # R2 presigned URL is signed as video/mp4
    ".gif": "video/mp4",  # presigned URL expects video/mp4; GIF workflows rare
    ".webm": "video/mp4",  # presigned URL expects video/mp4
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
}

VIDEO_EXTENSIONS = (".mp4", ".mov", ".gif", ".webm")


def wait_for_comfyui(timeout=STARTUP_TIMEOUT):
    """Wait for ComfyUI to be ready, retrying with backoff. Called once per cold start."""
    start = time.time()
    delay = 1  # start with 1s, double each retry up to 8s
    while time.time() - start < timeout:
        try:
            resp = requests.get(f"{COMFY_API}/system_stats", timeout=5)
            if resp.ok:
                elapsed = time.time() - start
                print(f"ComfyUI ready after {elapsed:.1f}s")
                return True
        except (requests.ConnectionError, requests.Timeout):
            pass  # Expected during startup
        except Exception as e:
            print(f"ComfyUI startup check unexpected error: {e}")
        elapsed = time.time() - start
        print(f"Waiting for ComfyUI... ({elapsed:.0f}s/{timeout}s)")
        time.sleep(delay)
        delay = min(delay * 2, 8)
    print(f"ComfyUI did not become ready within {timeout}s")
    return False


# Module-level flag — wait_for_comfyui() runs once on first job (cold start).
# Reset on ConnectionError to /prompt so a mid-session ComfyUI crash triggers re-check.
_comfyui_ready = False


def handler(job):
    """RunPod serverless handler."""
    global _comfyui_ready
    if not _comfyui_ready:
        if not wait_for_comfyui():
            return {"error": f"ComfyUI failed to start within {STARTUP_TIMEOUT}s"}
        _comfyui_ready = True

    job_input = job["input"]

    workflow = job_input.get("workflow")
    r2_upload_url = job_input.get("r2_upload_url")
    r2_thumb_upload_url = job_input.get("r2_thumb_upload_url")

    if not workflow:
        return {"error": "No workflow provided"}

    try:
        # Submit workflow to local ComfyUI
        response = requests.post(
            f"{COMFY_API}/prompt",
            json={"prompt": workflow},
            timeout=10,
        )

        # Parse ComfyUI validation errors before raise_for_status
        if not response.ok:
            error_body = {}
            try:
                error_body = response.json()
            except Exception:
                pass
            node_errors = error_body.get("node_errors", {})
            err_msg = error_body.get("error", {}).get("message", response.text[:500])
            print(f"ComfyUI /prompt rejected workflow ({response.status_code}): {err_msg}")
            if node_errors:
                print(f"Node errors: {json.dumps(node_errors, indent=2)[:1000]}")
            return {"error": f"Workflow validation failed: {err_msg}"}

        prompt_id = response.json()["prompt_id"]

        # Poll ComfyUI for completion — use longer timeout for video workflows
        is_likely_video = _workflow_is_video(workflow)
        timeout = POLL_TIMEOUT_VIDEO if is_likely_video else POLL_TIMEOUT_IMAGE
        result = poll_for_completion(prompt_id, timeout=timeout)

        if result is None:
            return {"error": "Generation produced no output"}

        # Check if ComfyUI reported an error
        if isinstance(result, dict) and "error" in result:
            return result

        output_path = result
        is_video = output_path.endswith(VIDEO_EXTENSIONS)
        ext = Path(output_path).suffix.lower()
        content_type = CONTENT_TYPES.get(ext, "application/octet-stream")

        # If presigned URLs are provided, upload directly to R2
        if r2_upload_url:
            file_size = Path(output_path).stat().st_size

            # Stream upload from disk to avoid loading large files into RAM
            with open(output_path, "rb") as f:
                upload_response = requests.put(
                    r2_upload_url,
                    data=f,
                    headers={
                        "Content-Type": content_type,
                        "Content-Length": str(file_size),
                    },
                    timeout=120,
                )
            upload_response.raise_for_status()
            print(f"Uploaded {file_size} bytes to R2 ({content_type})")

            # Generate and upload thumbnail (images only — video thumbnails not supported yet)
            if r2_thumb_upload_url and not is_video and HAS_PIL:
                try:
                    output_data = Path(output_path).read_bytes()
                    thumb_data = create_thumbnail(output_data)
                    if thumb_data:
                        thumb_response = requests.put(
                            r2_thumb_upload_url,
                            data=thumb_data,
                            headers={
                                "Content-Type": "image/jpeg",
                                "Content-Length": str(len(thumb_data)),
                            },
                            timeout=30,
                        )
                        if not thumb_response.ok:
                            print(f"Thumbnail upload failed: {thumb_response.status_code}")
                except Exception as e:
                    # Thumbnail failure is non-fatal
                    print(f"Thumbnail upload error: {e}")

            # Return confirmation (no base64 — Worker just marks job complete)
            return {
                "status": "uploaded",
                "size_bytes": file_size,
                "media_type": "video" if is_video else "image",
            }
        else:
            # Fallback: return base64 (backward compat with old Worker)
            output_data = Path(output_path).read_bytes()
            encoded = base64.b64encode(output_data).decode("utf-8")
            return {
                "images": [{"data": encoded}],
            }

    except requests.ConnectionError as e:
        # ComfyUI may have crashed — reset readiness flag for next invocation
        _comfyui_ready = False
        return {"error": f"ComfyUI connection lost: {e}"}
    except Exception as e:
        return {"error": str(e)}


def poll_for_completion(prompt_id, timeout=POLL_TIMEOUT_IMAGE):
    """Poll ComfyUI until the workflow completes.

    Returns:
        str: path to output file on success
        dict: {"error": "..."} if ComfyUI reports a workflow error
        None: if timeout reached with no output
    """
    start = time.time()
    attempts = 0

    while time.time() - start < timeout:
        attempts += 1
        try:
            resp = requests.get(
                f"{COMFY_API}/history/{prompt_id}",
                timeout=5,
            )
            if resp.ok:
                history = resp.json()
                if prompt_id in history:
                    job_data = history[prompt_id]

                    # Check for ComfyUI execution errors (OOM, missing model, bad node, etc.)
                    status_info = job_data.get("status", {})
                    status_str = status_info.get("status_str", "")
                    if status_str == "error":
                        error_msg = "ComfyUI workflow error"
                        messages = status_info.get("messages", [])
                        for msg_type, msg_data in messages:
                            if msg_type == "execution_error" and isinstance(msg_data, dict):
                                error_msg = msg_data.get("exception_message", error_msg)
                                node_id = msg_data.get("node_id", "unknown")
                                node_type = msg_data.get("node_type", "unknown")
                                print(f"ComfyUI execution error in node {node_id} ({node_type}): {error_msg}")
                        return {"error": f"ComfyUI error: {error_msg}"}

                    outputs = job_data.get("outputs", {})

                    # First pass: prefer type="output" items (final SaveImage/SaveVideo nodes)
                    # Second pass: fall back to any resolvable path (for workflows without type metadata)
                    for prefer_output_type in (True, False):
                        for node_id, node_output in outputs.items():
                            # Check videos/gifs first (explicit video output)
                            for media_key in ("videos", "gifs"):
                                if media_key in node_output:
                                    for item in node_output[media_key]:
                                        if prefer_output_type and item.get("type") != "output":
                                            continue
                                        path = resolve_output_path(item)
                                        if path:
                                            return path

                            # Check images
                            if "images" in node_output:
                                for item in node_output["images"]:
                                    if prefer_output_type and item.get("type") != "output":
                                        continue
                                    path = resolve_output_path(item)
                                    if path:
                                        return path

        except requests.Timeout:
            print(f"Poll timeout for {prompt_id} (attempt {attempts}), retrying...")
        except requests.ConnectionError as e:
            print(f"Connection error polling {prompt_id} (attempt {attempts}): {e}")
        except Exception as e:
            print(f"Unexpected error polling {prompt_id} (attempt {attempts}): {e}")

        time.sleep(POLL_INTERVAL)

    elapsed = time.time() - start
    print(f"poll_for_completion timed out for {prompt_id} after {elapsed:.0f}s ({attempts} attempts)")
    return None


def _workflow_is_video(workflow):
    """Heuristic: check if workflow contains video-related nodes."""
    workflow_str = json.dumps(workflow).lower()
    video_indicators = ["animatediff", "video", "svd", "wan2.1", "cogvideox", "hunyuan"]
    return any(indicator in workflow_str for indicator in video_indicators)


def resolve_output_path(item):
    """Resolve a ComfyUI output item to a filesystem path, with traversal protection."""
    filename = item.get("filename")
    if not filename:
        return None
    subfolder = item.get("subfolder", "")
    base = Path(COMFY_OUTPUT_DIR).resolve()
    path = (base / subfolder / filename).resolve()
    # Reject paths that escape the output directory
    if not path.is_relative_to(base):
        print(f"Path traversal attempt blocked: {path}")
        return None
    if path.exists():
        return str(path)
    return None


def create_thumbnail(image_data, max_size=256):
    """Create a JPEG thumbnail from image data."""
    if not HAS_PIL:
        return None
    try:
        img = Image.open(io.BytesIO(image_data))
        img.thumbnail((max_size, max_size), Image.LANCZOS)
        # Convert RGBA/P/LA to RGB for JPEG compatibility
        if img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")
        buffer = io.BytesIO()
        img.save(buffer, format="JPEG", quality=80)
        return buffer.getvalue()
    except Exception as e:
        print(f"Thumbnail generation failed: {e}")
        return None


runpod.serverless.start({"handler": handler})
