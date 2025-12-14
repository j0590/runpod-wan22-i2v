FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV TORCH_CUDA_ARCH_LIST="9.0"
ENV FORCE_CUDA=1
ENV MAX_JOBS=16

# --------------------
# System dependencies
# --------------------
RUN apt-get update && apt-get install -y \
    git curl wget aria2 ffmpeg \
    build-essential ninja-build pkg-config \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

WORKDIR /workspace

# --------------------
# Python base tooling
# --------------------
RUN python -m pip install --upgrade pip setuptools wheel

# --------------------
# Torch 2.8.0 + CUDA 12.8
# --------------------
RUN pip install \
    torch==2.8.0+cu128 \
    torchvision==0.19.0+cu128 \
    torchaudio==2.8.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128

# --------------------
# Core Python deps used by nodes
# --------------------
RUN pip install \
    numpy scipy einops timm psutil tqdm \
    safetensors huggingface_hub accelerate \
    sentencepiece protobuf \
    onnx onnxruntime-gpu \
    opencv-contrib-python

# --------------------
# SageAttention (compiled ONCE here)
# --------------------
RUN git clone https://github.com/Dao-AILab/sageattention.git && \
    cd sageattention && \
    pip install . --no-build-isolation && \
    cd .. && rm -rf sageattention

# Optional acceleration
RUN pip install xformers --no-deps || true

# --------------------
# Start script
# --------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8188
CMD ["/start.sh"]
