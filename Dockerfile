FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1 PYTHONUNBUFFERED=1 CMAKE_BUILD_PARALLEL_LEVEL=8
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip curl ffmpeg ninja-build git aria2 git-lfs wget vim libgl1 libglib2.0-0 build-essential gcc ca-certificates && ln -sf /usr/bin/python3.12 /usr/bin/python && ln -sf /usr/bin/pip3 /usr/bin/pip && python3.12 -m venv /opt/venv && git lfs install && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip setuptools wheel packaging
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
RUN pip install pyyaml gdown triton comfy-cli opencv-python
RUN /usr/bin/yes | comfy --workspace /ComfyUI install
COPY start.sh /start.sh
COPY moeksampler.json /moeksampler.json
RUN chmod +x /start.sh
EXPOSE 8188
CMD ["/start.sh"]
