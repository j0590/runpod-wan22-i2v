# 1. EXACT HEAREMEN BASE
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# 2. EXACT HEAREMEN ENV FLAGS
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

# 3. EXACT HEAREMEN SYSTEM INSTALL
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev \
        python3-pip \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 build-essential gcc && \
    \
    # Symlink Python 3.12
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    \
    # Create venv
    python3.12 -m venv /opt/venv && \
    \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4. ACTIVATE VENV
ENV PATH="/opt/venv/bin:$PATH"

# 5. EXACT HEAREMEN TORCH INSTALL (Nightly cu128)
# Using cache mount to prevent OOM
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128

# 6. PYTHON TOOLS
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel

# 7. RUNTIME LIBS
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install pyyaml gdown triton comfy-cli jupyterlab jupyterlab-lsp \
        jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter opencv-python

# 8. COMFYUI INSTALL
RUN --mount=type=cache,target=/root/.cache/pip \
    /usr/bin/yes | comfy --workspace /ComfyUI install

# 9. START SCRIPT
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
