FROM runpod/worker-comfyui:5.3.0-base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Update ComfyUI to latest version (required for Z-Image/Lumina2 support)
RUN cd /comfyui && git pull && pip install -r requirements.txt

# Update ComfyUI Manager to latest
RUN cd /comfyui/custom_nodes/ComfyUI-Manager && git pull

# Configure ComfyUI Manager security level
RUN mkdir -p /comfyui/user/__manager
RUN printf "[default]\nsecurity_level = weak\n" > /comfyui/user/__manager/config.ini

# Install custom nodes
RUN comfy-node-install https://github.com/chengzeyi/Comfy-WaveSpeed
RUN comfy-node-install https://github.com/laksjdjf/Batch-Condition-ComfyUI
RUN comfy-node-install https://github.com/shadowcz007/comfyui-ultralytics-yolo
RUN comfy-node-install https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch
RUN comfy-node-install https://github.com/yolain/ComfyUI-Easy-Use
RUN comfy-node-install https://github.com/pythongosssss/ComfyUI-Custom-Scripts

# Install additional Python dependencies that custom nodes might need
RUN pip install --no-cache-dir \
    ultralytics \
    opencv-python-headless \
    scikit-image \
    onnxruntime-gpu

# Pre-download YOLO model to avoid first-run delays
RUN mkdir -p /comfyui/models/ultralytics/bbox
RUN wget -q -O /comfyui/models/ultralytics/bbox/face_yolov8m.pt \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml
