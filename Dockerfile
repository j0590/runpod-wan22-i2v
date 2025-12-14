FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
SHELL ["/bin/bash","-lc"]
ENV DEBIAN_FRONTEND=noninteractive PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_PREFER_BINARY=1 PYTHONUNBUFFERED=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH" PIP_DEFAULT_TIMEOUT=120
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libswresample-dev && rm -rf /var/lib/apt/lists/* && git lfs install && python -m venv "$VIRTUAL_ENV" && python -m pip install --no-cache-dir -U pip setuptools wheel packaging
RUN if [[ "${TARGETARCH:-amd64}" == "amd64" ]]; then python -m pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128 --extra-index-url https://pypi.org/simple; else python -m pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple; fi && python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
RUN python -m pip install --no-cache-dir comfy-cli
RUN /usr/bin/yes | comfy --workspace /ComfyUI install
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
