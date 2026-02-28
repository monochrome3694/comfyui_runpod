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

RUN apt-get update && apt-get install -y aria2 && rm -rf /var/lib/apt/lists/*

# ============================================
# CREATE MODEL DIRECTORIES
# ============================================

RUN mkdir -p /comfyui/models/diffusion_models \
    /comfyui/models/text_encoders \
    /comfyui/models/vae

# ============================================
# Z-IMAGE MODELS (parallel download)
# ============================================

RUN printf '%s\n' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors' \
    '  out=/comfyui/models/diffusion_models/z_image_turbo_bf16.safetensors' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors' \
    '  out=/comfyui/models/text_encoders/qwen_3_4b.safetensors' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors' \
    '  out=/comfyui/models/vae/ae.safetensors' \
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
# CONFIGURATION
# ============================================

COPY handler.py /handler.py

ENV PYTORCH_ALLOC_CONF=expandable_segments:True
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --highvram|g' /start.sh
