FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_PREFER_BINARY=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH" CUDA_HOME=/usr/local/cuda
SHELL ["/bin/bash","-lc"]
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && rm -rf /var/lib/apt/lists/* && git lfs install && python3.12 -m venv /opt/venv && python -m pip install --no-cache-dir --upgrade pip setuptools wheel packaging
RUN python -m pip install --no-cache-dir gdown opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx onnxruntime-gpu pyyaml
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI && python -m pip install --no-cache-dir -r /ComfyUI/requirements.txt && python -m pip install --no-cache-dir "comfyui-frontend-package>=1.33.13"
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
