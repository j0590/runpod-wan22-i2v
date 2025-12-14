FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONUNBUFFERED=1 VIRTUAL_ENV=/opt/venv PATH="/opt/venv/bin:$PATH" PIP_PREFER_BINARY=1 CMAKE_BUILD_PARALLEL_LEVEL=8 TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0"
ARG TORCH_VERSION=2.8.0
ARG TORCHVISION_VERSION=0.23.0
ARG TORCHAUDIO_VERSION=2.8.0
ARG CUDA_TAG=cu128
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip python-is-python3 git git-lfs ca-certificates curl wget aria2 jq unzip build-essential cmake ninja-build pkg-config ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && rm -rf /var/lib/apt/lists/* && git lfs install && python3 -m venv "$VIRTUAL_ENV" && python -m pip install --no-cache-dir -U pip setuptools wheel packaging
RUN python -m pip install --no-cache-dir --upgrade "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" "torchaudio==${TORCHAUDIO_VERSION}" --index-url "https://download.pytorch.org/whl/${CUDA_TAG}" --extra-index-url "https://pypi.org/simple" || (python -m pip install --no-cache-dir --pre torch torchvision torchaudio --index-url "https://download.pytorch.org/whl/nightly/${CUDA_TAG}" --extra-index-url "https://pypi.org/simple")
RUN python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
RUN python -m pip install --no-cache-dir ninja pyyaml gdown triton
RUN git clone --depth=1 https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && cd /tmp/SageAttention && (python -m pip install --no-cache-dir -v . || python -m pip install --no-cache-dir "https://huggingface.co/Kijai/PrecompiledWheels/resolve/main/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl") && python -c "import sageattention; print('sageattention ok')" && rm -rf /tmp/SageAttention
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN cd /ComfyUI && python -m pip install --no-cache-dir -r requirements.txt
RUN python -m pip install --no-cache-dir -U comfyui-frontend-package
RUN python -m pip install --no-cache-dir opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx onnxruntime-gpu
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh
WORKDIR /workspace
CMD ["/start.sh"]
