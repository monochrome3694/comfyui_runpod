FROM runpod/worker-comfyui:5.7.1-base

# Install pip dependencies for custom nodes
RUN pip install --no-cache-dir \
    # Core/shared
    ultralytics \
    opencv-python-headless \
    scikit-learn \
    scikit-image \
    scipy \
    matplotlib \
    pandas \
    numpy \
    Pillow \
    # Impact Pack
    segment-anything \
    dill \
    piexif \
    # Easy-Use
    diffusers \
    accelerate \
    lark \
    sentencepiece \
    spandrel \
    peft \
    # Essentials
    numba \
    colour-science \
    rembg \
    # Manager
    GitPython \
    typer \
    rich \
    toml \
    chardet \
    # LLM_party core
    beautifulsoup4 \
    langchain \
    langchain-community \
    langchain-openai \
    langchain-text-splitters \
    openai \
    anthropic \
    transformers \
    sentence-transformers \
    tiktoken \
    faiss-cpu \
    openpyxl \
    xlrd \
    docx2txt \
    pdfplumber \
    websocket-client \
    pytz \
    requests \
    httpx \
    tenacity \
    tabulate \
    markdown \
    markdownify \
    html5lib \
    json-repair \
    aisuite \
    timm \
    optimum \
    && rm -rf ~/.cache/pip /tmp/*

# Symlink custom_nodes from network volume
RUN rm -rf /comfyui/custom_nodes && \
    ln -sf /runpod-volume/ComfyUI/custom_nodes /comfyui/custom_nodes

# Point to Network Volume models
ADD extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# GPU optimization
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# Patch start.sh to add --highvram flag
RUN sed -i 's|python -u /comfyui/main.py|python -u /comfyui/main.py --highvram|g' /start.sh
