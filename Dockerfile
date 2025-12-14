FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3-pip python-is-python3 \
    git git-lfs ca-certificates curl wget aria2 jq unzip \
    build-essential cmake ninja-build pkg-config \
    ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# Seed ComfyUI source into the image so first boot can just copy it to /workspace
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI

COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /workspace
CMD ["/start.sh"]
