FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONUNBUFFERED=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH"
SHELL ["/bin/bash","-lc"]
ARG TORCH_VERSION=2.8.0
ARG TORCHVISION_VERSION=0.23.0
ARG TORCHAUDIO_VERSION=2.8.0
ARG CUDA_TAG=cu128
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-dev python3.12-venv python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && rm -rf /var/lib/apt/lists/* && git lfs install && python3.12 -m venv $VIRTUAL_ENV && python -m pip install --no-cache-dir -U pip setuptools wheel
RUN ARCH="${TARGETARCH:-}"; if [[ -z "$ARCH" ]]; then M="$(uname -m)"; if [[ "$M" == "x86_64" ]]; then ARCH="amd64"; elif [[ "$M" == "aarch64" ]]; then ARCH="arm64"; else ARCH="$M"; fi; fi; echo "resolved_arch=$ARCH" && if [[ "$ARCH" == "amd64" ]]; then python -m pip install --no-cache-dir --upgrade "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}" --index-url "https://download.pytorch.org/whl/${CUDA_TAG}_full" --extra-index-url "https://pypi.org/simple" && python -m pip install --no-cache-dir --upgrade "triton==3.4.0" --index-url "https://download.pytorch.org/whl"; elif [[ "$ARCH" == "arm64" ]]; then python -m pip install --no-cache-dir --upgrade "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}"; else echo "Unsupported arch: $ARCH" && exit 1; fi && python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
RUN python -m pip install --no-cache-dir ninja
RUN python -m pip install --no-cache-dir sageattention || (git clone --depth=1 https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && cd /tmp/SageAttention && TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0" python -m pip install --no-cache-dir -v .)
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN cd /ComfyUI && python -m pip install --no-cache-dir -r requirements.txt && python -m pip install --no-cache-dir -U comfyui-frontend-package
RUN ARCH="${TARGETARCH:-}"; if [[ -z "$ARCH" ]]; then M="$(uname -m)"; [[ "$M" == "x86_64" ]] && ARCH="amd64" || ([[ "$M" == "aarch64" ]] && ARCH="arm64" || ARCH="$M"); fi; if [[ "$ARCH" == "amd64" ]]; then python -m pip install --no-cache-dir opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx onnxruntime-gpu; else python -m pip install --no-cache-dir opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx onnxruntime; fi
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
