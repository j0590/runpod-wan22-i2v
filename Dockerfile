FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONUNBUFFERED=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH"
SHELL ["/bin/bash","-lc"]
ARG TARGETARCH
ARG CUDA_TAG=cu128
ARG TORCH_VERSION=2.8.0
ARG TORCHVISION_VERSION=0.23.0
ARG TORCHAUDIO_VERSION=2.8.0
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && rm -rf /var/lib/apt/lists/* && git lfs install && python3 -m venv "${VIRTUAL_ENV}" && python -m pip install --no-cache-dir -U pip setuptools wheel
RUN ARCH="${TARGETARCH}"; if [[ -z "${ARCH}" ]]; then M="$(uname -m)"; if [[ "${M}" == "x86_64" ]]; then ARCH="amd64"; elif [[ "${M}" == "aarch64" ]]; then ARCH="arm64"; else ARCH="${M}"; fi; fi; echo "TARGETARCH=${TARGETARCH} resolved_arch=${ARCH}" && if [[ "${ARCH}" == "amd64" ]]; then python -m pip install --no-cache-dir --upgrade "torch==${TORCH_VERSION}+${CUDA_TAG}" "torchvision==${TORCHVISION_VERSION}+${CUDA_TAG}" "torchaudio==${TORCHAUDIO_VERSION}+${CUDA_TAG}" --extra-index-url "https://download.pytorch.org/whl/${CUDA_TAG}"; elif [[ "${ARCH}" == "arm64" ]]; then python -m pip install --no-cache-dir --upgrade "torch==${TORCH_VERSION}+cpu" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}" --extra-index-url "https://download.pytorch.org/whl/cpu"; else echo "Unsupported arch: ${ARCH}" && exit 1; fi && python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
RUN python -m pip install --no-cache-dir ninja
RUN python -m pip install --no-cache-dir sageattention || (git clone --depth=1 https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && cd /tmp/SageAttention && python -m pip install --no-cache-dir -v .)
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN cd /ComfyUI && python -m pip install --no-cache-dir -r requirements.txt
RUN python -m pip install --no-cache-dir -U comfyui-frontend-package
RUN python -m pip install --no-cache-dir opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx && (python -m pip install --no-cache-dir onnxruntime-gpu || python -m pip install --no-cache-dir onnxruntime)
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
