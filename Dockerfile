FROM runpod/worker-comfyui:5.7.1-base

# ============================================
# UPDATE COMFYUI TO LATEST VERSION
# ============================================

RUN cd /comfyui && \
    git pull origin master && \
    pip install --no-cache-dir -r requirements.txt && \
    rm -rf ~/.cache/pip /tmp/*

# ============================================
# SYSTEM DEPENDENCIES
# ============================================

RUN apt-get update && apt-get install -y ffmpeg aria2 && rm -rf /var/lib/apt/lists/*

# ============================================
# PYTHON DEPENDENCIES
# ============================================

RUN pip install --no-cache-dir \
    ultralytics \
    opencv-python-headless \
    scikit-learn \
    scikit-image \
    scipy \
    segment-anything \
    onnxruntime \
    transformers \
    accelerate \
    safetensors \
    einops \
    imageio \
    imageio-ffmpeg \
    av \
    kornia \
    dill \
    piexif \
    openai \
    matplotlib \
    ftfy \
    regex \
    tqdm \
    pyyaml \
    omegaconf \
    aiohttp \
    huggingface_hub \
    && rm -rf ~/.cache/pip /tmp/*

# ============================================
# CREATE MODEL DIRECTORIES
# ============================================

RUN mkdir -p /comfyui/models/diffusion_models \
    /comfyui/models/text_encoders \
    /comfyui/models/vae \
    /comfyui/models/checkpoints \
    /comfyui/models/ultralytics/bbox \
    /comfyui/models/ultralytics/segm

# ============================================
# Z-IMAGE + ANIME MODELS (parallel download)
# ============================================

RUN printf '%s\n' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors' \
    '  out=/comfyui/models/diffusion_models/z_image_turbo_bf16.safetensors' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors' \
    '  out=/comfyui/models/text_encoders/qwen_3_4b.safetensors' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors' \
    '  out=/comfyui/models/vae/ae.safetensors' \
    'https://civitai.com/api/download/models/1421930?type=Model&format=SafeTensor&size=full&fp=fp16&token=d250e4ca5d542a73d2d8d74727679ddc' \
    '  out=/comfyui/models/checkpoints/personaStyle_Ilxl10Noob.safetensors' \
    'https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt' \
    '  out=/comfyui/models/ultralytics/bbox/face_yolov8m.pt' \
    'https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt' \
    '  out=/comfyui/models/ultralytics/segm/person_yolov8m-seg.pt' \
    > /tmp/downloads.txt && \
    aria2c -i /tmp/downloads.txt \
        -j 10 \
        -x 16 \
        -s 16 \
        --file-allocation=none \
        --console-log-level=warn \
        --summary-interval=30 \
        --connect-timeout=30 \
        --timeout=600 \
        --max-tries=3 \
        --retry-wait=5 && \
    rm /tmp/downloads.txt

# ============================================
# CUSTOM NODES
# ============================================

RUN cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git comfyui-custom-scripts && \
    git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git comfyui-inpaint-cropandstitch && \
    git clone --depth 1 https://github.com/tusharbhutt/Endless-Nodes.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use && \
    git clone --depth 1 https://github.com/liuqianhonga/ComfyUI-Image-Compressor.git ComfyUI-Image-Compressor && \
    git clone --depth 1 https://github.com/laksjdjf/Batch-Condition-ComfyUI.git Batch-Condition-ComfyUI && \
    git clone --depth 1 https://github.com/Extraltodeus/Skimmed_CFG.git Skimmed_CFG && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone --depth 1 https://github.com/chengzeyi/Comfy-WaveSpeed.git

# Add llm_party_lite
ADD llm_party_lite /comfyui/custom_nodes/llm_party_lite

# Install all custom node requirements
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
    pip install --no-cache-dir -r "$req" 2>/dev/null || true; \
    done && rm -rf /tmp/*

# ============================================
# CONFIGURATION
# ============================================

# GPU optimization
ENV PYTORCH_ALLOC_CONF=expandable_segments:True
