FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    GIT_TERMINAL_PROMPT=0

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    git git-lfs curl wget aria2 unzip rsync \
    build-essential cmake ninja-build \
    ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
 && rm -rf /var/lib/apt/lists/* \
 && git lfs install

# Seed a copy of ComfyUI inside the image (first boot faster + reliable)
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI

COPY start.sh /start.sh
COPY moeksampler.json /moeksampler.json
RUN chmod +x /start.sh

CMD ["/start.sh"]
