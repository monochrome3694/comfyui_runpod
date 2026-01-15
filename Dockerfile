FROM runpod/worker-comfyui:5.6.0-base

# Install custom nodes
RUN comfy-node-install https://github.com/chengzeyi/Comfy-WaveSpeed
RUN comfy-node-install https://github.com/laksjdjf/Batch-Condition-ComfyUI
RUN comfy-node-install https://github.com/shadowcz007/comfyui-ultralytics-yolo
RUN comfy-node-install https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch
RUN comfy-node-install https://github.com/yolain/ComfyUI-Easy-Use
RUN comfy-node-install https://github.com/pythongosssss/ComfyUI-Custom-Scripts

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml
