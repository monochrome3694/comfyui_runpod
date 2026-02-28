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
# FACE DETECTION MODEL
# ============================================

RUN aria2c -x 16 -s 16 --file-allocation=none \
    -o /comfyui/models/ultralytics/bbox/face_yolov8m.pt \
    'https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt'

# ============================================
# ILLUSTRIOUS CHECKPOINT (update token if expired)
# ============================================

RUN aria2c -x 16 -s 16 --file-allocation=none \
    --connect-timeout=30 --timeout=600 --max-tries=3 --retry-wait=5 \
    -o /comfyui/models/checkpoints/personaStyle_Ilxl10Noob.safetensors \
    'https://civitai.com/api/download/models/1421930?type=Model&format=SafeTensor&size=full&fp=fp16&token=d544ac1825829086f941063614663856'

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
