# 1. BASE IMAGE (Matches your logs)
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

# 2. ENV FLAGS
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    PATH="/opt/venv/bin:$PATH"

# 3. SYSTEM INSTALL (Added python3-dev for Insightface)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev python3-dev \
        python3-pip build-essential \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        libgl1 libglib2.0-0 google-perftools && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    python3.12 -m venv /opt/venv && \
    # Upgrade pip first to handle modern wheels
    /opt/venv/bin/pip install --upgrade pip setuptools wheel && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4. INSTALL TORCH (Using the PROVEN URL from your logs)
# We use --no-cache-dir to avoid OOM during the build
RUN pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 \
    --index-url https://download.pytorch.org/whl/cu128

# 5. [CRITICAL FIX] INSTALL INSIGHTFACE & ONNX HERE
# Building this at runtime fails because Python.h is missing. 
# Building it here works because we have the dev tools loaded.
RUN pip install --no-cache-dir insightface onnxruntime-gpu

# 6. RUNTIME LIBS
RUN pip install --no-cache-dir pyyaml gdown triton comfy-cli jupyterlab jupyterlab-lsp \
        jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter opencv-python

# 7. INSTALL COMFYUI
RUN /usr/bin/yes | comfy --workspace /ComfyUI install

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
