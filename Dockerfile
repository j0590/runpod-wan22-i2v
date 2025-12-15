# 1. EXACT HEAREMEN BASE (Verified Working)
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    PATH="/opt/venv/bin:$PATH"

# 2. SYSTEM DEPS (With Cache Mounts to prevent apt failures)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev \
        python3-pip build-essential \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 google-perftools && \
    \
    # Symlink Python 3.12
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    \
    # Setup Venv
    python3.12 -m venv /opt/venv && \
    \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. INSTALL TORCH NIGHTLY (Crucial: Uses Cache Mount to prevent OOM)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu128

# 4. PYTHON TOOLS
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel pyyaml gdown triton comfy-cli \
    jupyterlab ipykernel opencv-python

# 5. COMFYUI INSTALL
RUN --mount=type=cache,target=/root/.cache/pip \
    mkdir -p /ComfyUI && \
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI && \
    pip install -r /ComfyUI/requirements.txt

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
