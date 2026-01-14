FROM runpod/worker-comfyui:5.3.0-base

# Configure ComfyUI Manager security level
RUN mkdir -p /comfyui/user/__manager
RUN echo "[default]\nsecurity_level = weak" > /comfyui/user/__manager/config.ini

# Install custom nodes
RUN comfy-node-install https://github.com/chengzeyi/Comfy-WaveSpeed
RUN comfy-node-install https://github.com/laksjdjf/Batch-Condition-ComfyUI
RUN comfy-node-install https://github.com/shadowcz007/comfyui-ultralytics-yolo
RUN comfy-node-install https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch
RUN comfy-node-install https://github.com/yolain/ComfyUI-Easy-Use
RUN comfy-node-install https://github.com/pythongosssss/ComfyUI-Custom-Scripts

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml
