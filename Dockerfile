FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONUNBUFFERED=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH" CUDA_HOME=/usr/local/cuda
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && rm -rf /var/lib/apt/lists/* && git lfs install && python3 -m venv $VIRTUAL_ENV && pip install --no-cache-dir -U pip setuptools wheel
ARG TORCH_VERSION=2.8.0
ARG TORCHVISION_VERSION=0.23.0
ARG TORCHAUDIO_VERSION=2.8.0
ARG CUDA_TAG=cu128
RUN pip install --no-cache-dir --upgrade "torch==${TORCH_VERSION}+${CUDA_TAG}" "torchvision==${TORCHVISION_VERSION}+${CUDA_TAG}" "torchaudio==${TORCHAUDIO_VERSION}+${CUDA_TAG}" --extra-index-url "https://download.pytorch.org/whl/${CUDA_TAG}" && python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
RUN pip install --no-cache-dir ninja
RUN git clone --depth=1 https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && cd /tmp/SageAttention && TORCH_CUDA_ARCH_LIST="8.9;12.0" MAX_JOBS=8 NVCC_APPEND_FLAGS="--threads 8" pip install --no-cache-dir --no-build-isolation -v . && python -c "import sageattention; print('sageattention', getattr(sageattention,'__version__','unknown'))" && rm -rf /tmp/SageAttention
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN cd /ComfyUI && pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -U comfyui-frontend-package
RUN pip install --no-cache-dir opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx onnxruntime-gpu
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
