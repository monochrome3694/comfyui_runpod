FROM runpod/worker-comfyui:5.7.1-base

# Install pip dependencies for custom nodes on network volume
RUN pip install --no-cache-dir \
    ultralytics \
    opencv-python-headless \
    scikit-learn \
    scikit-image \
    onnxruntime-gpu \
    langchain \
    langchain-community \
    langchain-openai \
    openai \
    anthropic \
    transformers \
    sentence-transformers \
    piexif \
    aisuite

# Symlink custom_nodes from network volume
RUN rm -rf /comfyui/custom_nodes && \
    ln -sf /runpod-volume/ComfyUI/custom_nodes /comfyui/custom_nodes

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# GPU optimization
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# Use high VRAM mode for 24GB GPUs (4090/5090)
ENV COMFYUI_FLAGS="--highvram"
