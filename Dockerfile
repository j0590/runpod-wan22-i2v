# 1. BASE: Use the "Golden Standard" for AI (Ubuntu 22.04 + CUDA 12.4)
# This avoids the Python 3.12 "externally managed" errors and wheel incompatibilities.
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 AS base

# 2. ENV: Standard Optimization Flags
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# 3. SYSTEM: Install Python 3.11 (The "Sweet Spot" for ComfyUI)
# We use the 'deadsnakes' PPA to get modern Python on 22.04
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.11 python3.11-venv python3.11-dev \
        python3-pip build-essential \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 google-perftools && \
    \
    # Create Virtual Env
    python3.11 -m venv /opt/venv && \
    \
    # Upgrade pip strictly inside the venv
    /opt/venv/bin/pip install --upgrade pip wheel setuptools && \
    \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4. TORCH: Install Stable Version (2.5.1 for CUDA 12.4)
# This wheel is 100% available and stable.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 \
    --index-url https://download.pytorch.org/whl/cu124

# 5. CORE: Install Common Tools
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel pyyaml gdown triton comfy-cli \
        jupyterlab jupyterlab-lsp jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter opencv-python

# 6. COMFY: Install Core
RUN --mount=type=cache,target=/root/.cache/pip \
    mkdir -p /ComfyUI && \
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI && \
    pip install -r /ComfyUI/requirements.txt

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
