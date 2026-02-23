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
POLL_TIMEOUT = 300  # 5 minutes


def handler(job):
    """RunPod serverless handler."""
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
        response.raise_for_status()
        prompt_id = response.json()["prompt_id"]

        # Poll ComfyUI for completion
        output_path = poll_for_completion(prompt_id)

        if not output_path:
            return {"error": "Generation produced no output"}

        # Read the generated file
        output_data = Path(output_path).read_bytes()
        is_video = output_path.endswith((".mp4", ".mov", ".gif", ".webm"))

        # If presigned URLs are provided, upload directly to R2
        if r2_upload_url:
            content_type = "video/mp4" if is_video else "image/png"

            # Upload full output
            upload_response = requests.put(
                r2_upload_url,
                data=output_data,
                headers={"Content-Type": content_type},
                timeout=120,
            )
            upload_response.raise_for_status()

            # Generate and upload thumbnail (for images only)
            if r2_thumb_upload_url and not is_video and HAS_PIL:
                thumb_data = create_thumbnail(output_data)
                if thumb_data:
                    try:
                        thumb_response = requests.put(
                            r2_thumb_upload_url,
                            data=thumb_data,
                            headers={"Content-Type": "image/jpeg"},
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
                "size_bytes": len(output_data),
                "media_type": "video" if is_video else "image",
            }
        else:
            # Fallback: return base64 (backward compat with old Worker)
            encoded = base64.b64encode(output_data).decode("utf-8")
            return {
                "images": [{"data": encoded}],
            }

    except Exception as e:
        return {"error": str(e)}


def poll_for_completion(prompt_id, timeout=POLL_TIMEOUT):
    """Poll ComfyUI until the workflow completes."""
    start = time.time()

    while time.time() - start < timeout:
        try:
            resp = requests.get(
                f"{COMFY_API}/history/{prompt_id}",
                timeout=5,
            )
            if resp.ok:
                history = resp.json()
                if prompt_id in history:
                    outputs = history[prompt_id].get("outputs", {})
                    for node_id, node_output in outputs.items():
                        # Check videos/gifs first (explicit video output)
                        for media_key in ("videos", "gifs"):
                            if media_key in node_output:
                                for item in node_output[media_key]:
                                    path = resolve_output_path(item)
                                    if path:
                                        return path

                        # Check images
                        if "images" in node_output:
                            for item in node_output["images"]:
                                path = resolve_output_path(item)
                                if path:
                                    return path
        except Exception:
            pass

        time.sleep(POLL_INTERVAL)

    return None


def resolve_output_path(item):
    """Resolve a ComfyUI output item to a filesystem path."""
    filename = item.get("filename")
    if not filename:
        return None
    subfolder = item.get("subfolder", "")
    path = Path(COMFY_OUTPUT_DIR) / subfolder / filename
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
        buffer = io.BytesIO()
        img.save(buffer, format="JPEG", quality=80)
        return buffer.getvalue()
    except Exception:
        return None


runpod.serverless.start({"handler": handler})
