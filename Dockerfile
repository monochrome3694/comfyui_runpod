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
    huggingface_hub \
    && rm -rf ~/.cache/pip /tmp/*

# ============================================
# CREATE MODEL DIRECTORIES
# ============================================

RUN mkdir -p /comfyui/models/diffusion_models \
    /comfyui/models/text_encoders \
    /comfyui/models/vae \
    /comfyui/models/loras \
    /comfyui/models/LLM/Florence-2-large-PromptGen-v2.0

# ============================================
# WAN 2.2 VIDEO MODELS (parallel download)
# ============================================

RUN printf '%s\n' \
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
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/model.safetensors' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/model.safetensors' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/config.json' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/config.json' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/configuration_florence2.py' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/configuration_florence2.py' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/modeling_florence2.py' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/modeling_florence2.py' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/processing_florence2.py' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/processing_florence2.py' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/preprocessor_config.json' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/preprocessor_config.json' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/generation_config.json' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/generation_config.json' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/tokenizer.json' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/tokenizer.json' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/tokenizer_config.json' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/tokenizer_config.json' \
    'https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v2.0/resolve/main/vocab.json' \
    '  out=/comfyui/models/LLM/Florence-2-large-PromptGen-v2.0/vocab.json' \
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
# CUSTOM NODES (parallel git clones)
# ============================================

RUN rm -rf /comfyui/custom_nodes/* && cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git & \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git & \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git & \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git & \
    git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git comfyui-custom-scripts & \
    git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git comfyui-inpaint-cropandstitch & \
    git clone --depth 1 https://github.com/tusharbhutt/Endless-Nodes.git & \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use & \
    git clone --depth 1 https://github.com/liuqianhonga/ComfyUI-Image-Compressor.git ComfyUI-Image-Compressor & \
    git clone --depth 1 https://github.com/laksjdjf/Batch-Condition-ComfyUI.git Batch-Condition-ComfyUI & \
    git clone --depth 1 https://github.com/Extraltodeus/Skimmed_CFG.git Skimmed_CFG & \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git & \
    git clone --depth 1 https://github.com/kijai/ComfyUI-Florence2.git & \
    git clone --depth 1 https://github.com/chengzeyi/Comfy-WaveSpeed.git & \
    wait

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
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --highvram|g' /start.sh
