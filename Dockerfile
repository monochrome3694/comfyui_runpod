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
# PYTHON DEPENDENCIES (Impact-Pack requirements)
# ============================================

RUN pip install --no-cache-dir \
    ultralytics \
    opencv-python-headless \
    scikit-image \
    scipy \
    segment-anything \
    onnxruntime \
    && rm -rf ~/.cache/pip /tmp/*

# ============================================
# CREATE MODEL DIRECTORIES
# ============================================

RUN mkdir -p /comfyui/models/checkpoints \
    /comfyui/models/ultralytics/bbox

# ============================================
# ILLUSTRIOUS MODEL + FACE DETECTION (parallel download)
# ============================================

RUN printf '%s\n' \
    'https://civitai.com/api/download/models/1421930?type=Model&format=SafeTensor&size=full&fp=fp16&token=d250e4ca5d542a73d2d8d74727679ddc' \
    '  out=/comfyui/models/checkpoints/personaStyle_Ilxl10Noob.safetensors' \
    'https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt' \
    '  out=/comfyui/models/ultralytics/bbox/face_yolov8m.pt' \
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
# CUSTOM NODES (only what the workflow needs)
# ============================================

# Face detection + inpainting pipeline
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git

# Inpaint crop & stitch
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git comfyui-inpaint-cropandstitch

# String manipulation (StringConcatenate, RegexReplace)
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/tusharbhutt/Endless-Nodes.git

# String Input node
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git ComfyUI-Easy-Use

# Skimmed CFG
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/Extraltodeus/Skimmed_CFG.git Skimmed_CFG

# First Block Cache for speed
RUN cd /comfyui/custom_nodes && git clone --depth 1 https://github.com/chengzeyi/Comfy-WaveSpeed.git

# JSON parsing (json_extractor, json_get_value)
ADD llm_party_lite /comfyui/custom_nodes/llm_party_lite

# Install all custom node requirements
RUN for req in /comfyui/custom_nodes/*/requirements.txt; do \
    pip install --no-cache-dir -r "$req" 2>/dev/null || true; \
    done && rm -rf /tmp/*

# ============================================
# CONFIGURATION
# ============================================

COPY handler.py /handler.py

ENV PYTORCH_ALLOC_CONF=expandable_segments:True
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --highvram|g' /start.sh
