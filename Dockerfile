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
    git \
    wget \
    ffmpeg \
    build-essential \
    ninja-build \
    pkg-config \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# --------------------
# Python tooling
# --------------------
RUN python -m pip install --upgrade pip setuptools wheel

WORKDIR /workspace

# --------------------
# Torch 2.8.0 + CUDA 12.8
# --------------------
RUN pip install \
    torch==2.8.0+cu128 \
    torchvision==0.19.0+cu128 \
    torchaudio==2.8.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128

# --------------------
# Core Python deps (NO runtime installs later)
# --------------------
RUN pip install \
    numpy \
    scipy \
    einops \
    timm \
    sentencepiece \
    protobuf \
    safetensors \
    huggingface_hub \
    accelerate \
    onnx \
    onnxruntime-gpu \
    opencv-contrib-python \
    psutil \
    tqdm

# --------------------
# SageAttention (CRITICAL)
# --------------------
RUN git clone https://github.com/Dao-AILab/sageattention.git && \
    cd sageattention && \
    pip install . --no-build-isolation && \
    cd .. && rm -rf sageattention

# --------------------
# Optional but useful
# --------------------
RUN pip install xformers --no-deps || true

# --------------------
# ComfyUI
# --------------------
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

# --------------------
# Custom nodes (only what you use)
# --------------------
WORKDIR /workspace/ComfyUI/custom_nodes

RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone https://github.com/Hearmeman24/comfyui-wan.git && \
    git clone https://github.com/Miosp/ComfyUI-FBCNN.git

WORKDIR /workspace/ComfyUI

EXPOSE 8188

# --------------------
# Start command
# --------------------
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
