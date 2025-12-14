FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_PREFER_BINARY=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH"
SHELL ["/bin/bash","-lc"]
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libavformat-dev libavcodec-dev libavdevice-dev libavutil-dev libswscale-dev libswresample-dev && rm -rf /var/lib/apt/lists/* && git lfs install && python3.12 -m venv /opt/venv && python -m pip install --no-cache-dir --upgrade pip setuptools wheel packaging
RUN python -m pip install --no-cache-dir --upgrade comfy-cli gdown pyyaml
RUN if [[ "${TARGETARCH:-amd64}" == "amd64" ]]; then python -m pip uninstall -y torch torchvision torchaudio || true; python -m pip install --no-cache-dir torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128 --extra-index-url https://pypi.org/simple || python -m pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128 --extra-index-url https://pypi.org/simple; python -m pip freeze | grep -E "^(torch|torchvision|torchaudio)" > /opt/torch-constraint.txt || true; PIP_CONSTRAINT=/opt/torch-constraint.txt git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI && PIP_CONSTRAINT=/opt/torch-constraint.txt python -m pip install --no-cache-dir -r /ComfyUI/requirements.txt; else mkdir -p /ComfyUI; fi
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
