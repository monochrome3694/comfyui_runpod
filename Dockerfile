FROM runpod/worker-comfyui:5.7.1-base

# Install dependencies for custom nodes
RUN pip install --no-cache-dir \
    ultralytics \
    opencv-python-headless \
    scikit-learn \
    scikit-image \
    scipy \
    dill \
    piexif \
    segment-anything \
    openai \
    && rm -rf ~/.cache/pip /tmp/*

# Add llm_party_lite to staging location
ADD llm_party_lite /opt/llm_party_lite

# Symlink custom_nodes from network volume
RUN rm -rf /comfyui/custom_nodes && \
    ln -sf /runpod-volume/ComfyUI/custom_nodes /comfyui/custom_nodes
RUN mkdir -p /comfyui/models/ultralytics && \
    ln -sf /runpod-volume/ComfyUI/models/ultralytics/bbox /comfyui/models/ultralytics/bbox && \
    ln -sf /runpod-volume/ComfyUI/models/ultralytics/segm /comfyui/models/ultralytics/segm
# Copy llm_party_lite to network volume at startup (before ComfyUI starts)
RUN sed -i '2a mkdir -p /runpod-volume/ComfyUI/custom_nodes/llm_party_lite && cp -r /opt/llm_party_lite/* /runpod-volume/ComfyUI/custom_nodes/llm_party_lite/' /start.sh

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# GPU optimization + low VRAM
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --normalvram|g' /start.sh
