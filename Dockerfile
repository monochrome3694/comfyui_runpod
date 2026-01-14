# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# install custom nodes into comfyui (first node with --mode remote to fetch updated cache)
# Could not resolve unknown_registry custom node: ModelSamplingAuraFlow (no aux_id provided)
# Could not resolve unknown_registry custom node: ImageScaleToTotalPixels (no aux_id provided)
# Could not resolve unknown_registry custom node: ImageScaleToTotalPixels (no aux_id provided)
# Could not resolve unknown_registry custom node: CheckpointLoaderSimple (no aux_id provided)
# Could not resolve unknown_registry custom node: ApplyFBCacheOnModel (no aux_id provided)
# Could not resolve unknown_registry custom node: easy string (no aux_id provided)
# Could not resolve unknown_registry custom node: DetectByLabel (no aux_id provided)
# Could not resolve unknown_registry custom node: InpaintCropImproved (no aux_id provided)
# Could not resolve unknown_registry custom node: InpaintStitchImproved (no aux_id provided)
# Could not resolve unknown_registry custom node: StringConcatenate (no aux_id provided)
# Could not resolve unknown_registry custom node: String Input (no aux_id provided)

# download models into comfyui
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors --relative-path models/clip --filename qwen_3_4b.safetensors
RUN comfy model download --url https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors --relative-path models/vae --filename ae.safetensors
RUN comfy model download --url https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors --relative-path models/diffusion_models --filename z_image_turbo_bf16.safetensors
# RUN # Could not find URL for personaStyle_Ilxl10Noob.safetensors

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/
