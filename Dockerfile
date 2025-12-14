FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3-pip python-is-python3 \
    git git-lfs ca-certificates curl wget aria2 jq unzip \
    build-essential cmake ninja-build pkg-config \
    ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# 2. Install Python Dependencies (The Heavy Lifters)
# Installing these in the image prevents re-downloading 5GB+ on every start.

# Upgrade pip and install wheel/setuptools
RUN pip install --no-cache-dir -U pip setuptools wheel

# Install Torch 2.8.0 ecosystem (cu128)
# We use --no-cache-dir to keep image size smaller
RUN pip install --no-cache-dir \
    torch==2.8.0 \
    torchvision==0.23.0 \
    torchaudio==2.8.0 \
    --index-url https://download.pytorch.org/whl/cu128

# Install general build tools
RUN pip install --no-cache-dir ninja

# 3. Pre-install SageAttention (Required for Wan2.2 optimizations)
# Try pip first, then fallback to build from source if needed
RUN pip install --no-cache-dir sageattention || \
    (git clone --depth=1 https://github.com/thu-ml/SageAttention.git /tmp/SageAttention && \
    cd /tmp/SageAttention && \
    pip install --no-cache-dir -v .)

# 4. Prepare ComfyUI & Requirements
# We clone to a system location (/ComfyUI) so start.sh can copy it to /workspace later.
WORKDIR /
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI

# Install ComfyUI Core Requirements immediately
RUN cd /ComfyUI && pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -U comfyui-frontend-package

# 5. Pre-install Common Custom Node Requirements
# By installing these common packages now, we save time usually spent checking requirements.txt
RUN pip install --no-cache-dir \
    opencv-contrib-python \
    boto3 \
    tqdm \
    imageio \
    imageio-ffmpeg \
    scikit-image \
    onnx \
    onnxruntime-gpu

# Copy start script
COPY start.sh /start.sh
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

# Set working directory to workspace (where the persistent data will live)
WORKDIR /workspace

# Start!
CMD ["/start.sh"]
