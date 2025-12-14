FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
SHELL ["/bin/bash","-lc"]
ENV DEBIAN_FRONTEND=noninteractive PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONUNBUFFERED=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH" CUDA_HOME=/usr/local/cuda
ARG TARGETARCH
ARG TORCH_VERSION=2.8.0
ARG TORCHVISION_VERSION=0.23.0
ARG TORCHAUDIO_VERSION=2.8.0
ARG CUDA_TAG=cu128
ARG TORCH_CUDA_ARCH_LIST=8.9
ENV TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && rm -rf /var/lib/apt/lists/* && git lfs install && python3 -m venv ${VIRTUAL_ENV} && python -m pip install --no-cache-dir -U pip setuptools wheel
RUN ARCH="${TARGETARCH:-}"; if [[ -z "${ARCH}" ]]; then M="$(uname -m)"; if [[ "${M}" == "x86_64" ]]; then ARCH="amd64"; elif [[ "${M}" == "aarch64" ]]; then ARCH="arm64"; else ARCH="${M}"; fi; fi; echo "resolved_arch=${ARCH}"; if [[ "${ARCH}" == "amd64" ]]; then python -m pip install --no-cache-dir --index-url "https://download.pytorch.org/whl/${CUDA_TAG}" "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}" || python -m pip install --no-cache-dir --index-url "https://download.pytorch.org/whl/${CUDA_TAG}_full" "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}"; elif [[ "${ARCH}" == "arm64" ]]; then python -m pip install --no-cache-dir --index-url "https://download.pytorch.org/whl/cpu" "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}"; else echo "Unsupported arch: ${ARCH}" && exit 1; fi && python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
RUN python -m pip install --no-cache-dir ninja
RUN ARCH="${TARGETARCH:-}"; if [[ -z "${ARCH}" ]]; then M="$(uname -m)"; if [[ "${M}" == "x86_64" ]]; then ARCH="amd64"; elif [[ "${M}" == "aarch64" ]]; then ARCH="arm64"; else ARCH="${M}"; fi; fi; if [[ "${ARCH}" == "amd64" ]]; then python -m pip install --no-cache-dir sageattention || python -m pip install --no-cache-dir --no-build-isolation "git+https://github.com/thu-ml/SageAttention.git"; python -c "import sageattention; print('sageattention ok')"; else echo "Skipping SageAttention on ${ARCH}"; fi
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN cd /ComfyUI && python -m pip install --no-cache-dir -r requirements.txt
RUN python -m pip install --no-cache-dir -U comfyui-frontend-package
RUN ARCH="${TARGETARCH:-}"; if [[ -z "${ARCH}" ]]; then M="$(uname -m)"; if [[ "${M}" == "x86_64" ]]; then ARCH="amd64"; elif [[ "${M}" == "aarch64" ]]; then ARCH="arm64"; else ARCH="${M}"; fi; fi; python -m pip install --no-cache-dir opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx; if [[ "${ARCH}" == "amd64" ]]; then python -m pip install --no-cache-dir onnxruntime-gpu; else python -m pip install --no-cache-dir onnxruntime; fi
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
