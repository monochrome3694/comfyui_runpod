FROM runpod/worker-comfyui:5.7.1-base

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
    && rm -rf ~/.cache/pip /tmp/*

# ============================================
# CREATE MODEL DIRECTORIES
# ============================================

RUN mkdir -p /comfyui/models/diffusion_models \
    /comfyui/models/text_encoders \
    /comfyui/models/vae \
    /comfyui/models/checkpoints \
    /comfyui/models/loras \
    /comfyui/models/ultralytics/bbox \
    /comfyui/models/ultralytics/segm

# ============================================
# ALL MODELS (parallel download with aria2c)
# ============================================

RUN printf '%s\n' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors' \
    '  out=/comfyui/models/diffusion_models/z_image_turbo_bf16.safetensors' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors' \
    '  out=/comfyui/models/text_encoders/qwen_3_4b.safetensors' \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors' \
    '  out=/comfyui/models/vae/ae.safetensors' \
    'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors' \
    '  out=/comfyui/models/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors' \
    'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors' \
    '  out=/comfyui/models/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors' \
    'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors' \
    '  out=/comfyui/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors' \
    'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors' \
    '  out=/comfyui/models/vae/wan_2.1_vae.safetensors' \
    'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors' \
    '  out=/comfyui/models/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors' \
    'https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors' \
    '  out=/comfyui/models/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors' \
    'https://civitai.com/api/download/models/1421930?type=Model&format=SafeTensor&size=full&fp=fp16&token=d250e4ca5d542a73d2d8d74727679ddc' \
    '  out=/comfyui/models/checkpoints/personaStyle_Ilxl10Noob.safetensors' \
    'https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt' \
    '  out=/comfyui/models/ultralytics/bbox/face_yolov8m.pt' \
    'https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt' \
    '  out=/comfyui/models/ultralytics/segm/person_yolov8m-seg.pt' \
    > /tmp/downloads.txt && \
    aria2c -i /tmp/downloads.txt \
        -j 6 \
        -x 4 \
        -s 4 \
        --file-allocation=none \
        --console-log-level=warn \
        --summary-interval=10 && \
    rm /tmp/downloads.txt

# ============================================
# FLORENCE2 MODEL (uses huggingface-cli)
# ============================================

RUN pip install --no-cache-dir huggingface_hub && \
    huggingface-cli download MiaoshouAI/Florence-2-large-PromptGen-v2.0 \
    --local-dir /comfyui/models/LLM/Florence-2-large-PromptGen-v2.0 \
    --local-dir-use-symlinks False && \
    rm -rf ~/.cache/huggingface

# ============================================
# CUSTOM NODES (ALL EMBEDDED)
# ============================================

RUN rm -rf /comfyui/custom_nodes/* && \
    cd /comfyui/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git comfyui-custom-scripts && \
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git comfyui-inpaint-cropandstitch && \
    git clone https://github.com/tusharbhutt/Endless-Nodes.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use && \
    git clone https://github.com/liuqianhonga/ComfyUI-Image-Compressor.git ComfyUI-Image-Compressor && \
    git clone https://github.com/laksjdjf/Batch-Condition-ComfyUI.git Batch-Condition-ComfyUI && \
    git clone https://github.com/Extraltodeus/Skimmed_CFG.git Skimmed_CFG && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone https://github.com/kijai/ComfyUI-Florence2.git && \
    git clone https://github.com/chengzeyi/Comfy-WaveSpeed.git

# Add llm_party_lite
ADD llm_party_lite /comfyui/custom_nodes/llm_party_lite

# Install all custom node requirements
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
    pip install -q -r "$req" 2>/dev/null || true; \
    done && rm -rf ~/.cache/pip /tmp/*

# ============================================
# CONFIGURATION
# ============================================

# GPU optimization
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --normalvram|g' /start.sh
