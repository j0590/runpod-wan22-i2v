# Use multi-stage build with caching optimizations (The "Verified" Standard)
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# Consolidated environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    PATH="/opt/venv/bin:$PATH"

# Install System Dependencies & TCMalloc (Crucial for VRAM management)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev \
        python3-pip build-essential \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 google-perftools && \
    \
    # Set Python 3.12 as default
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    \
    # Create Virtual Env
    python3.12 -m venv /opt/venv && \
    \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Torch Nightly (Matching the 12.8 CUDA Driver)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128

# Core Python Tooling
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel pyyaml gdown triton comfy-cli \
        jupyterlab jupyterlab-lsp jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter opencv-python

# Install ComfyUI Core
RUN --mount=type=cache,target=/root/.cache/pip \
    mkdir -p /ComfyUI && \
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI && \
    pip install -r /ComfyUI/requirements.txt

COPY start.sh /start.sh
RUN chmod +x /start.sh

# We do NOT download models here. We do that in start.sh to keep the image small.
CMD ["/start.sh"]
