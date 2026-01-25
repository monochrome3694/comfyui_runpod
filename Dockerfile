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
    aisuite \
    beautifulsoup4 \
    protobuf \
    grpcio \
    transformers \
    && rm -rf ~/.cache/pip /tmp/*

# Symlink custom_nodes from network volume
RUN rm -rf /comfyui/custom_nodes && \
    ln -sf /runpod-volume/ComfyUI/custom_nodes /comfyui/custom_nodes

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# GPU optimization + high VRAM
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --highvram|g' /start.sh
