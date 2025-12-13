FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1 PYTHONUNBUFFERED=1 CMAKE_BUILD_PARALLEL_LEVEL=8
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip curl ffmpeg ninja-build git aria2 git-lfs wget vim libgl1 libglib2.0-0 build-essential gcc ca-certificates && ln -sf /usr/bin/python3.12 /usr/bin/python && ln -sf /usr/bin/pip3 /usr/bin/pip && python3.12 -m venv /opt/venv && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip && pip install packaging setuptools wheel
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

RUN pip install pyyaml gdown triton comfy-cli opencv-python
RUN /usr/bin/yes | comfy --workspace /ComfyUI install
RUN mkdir -p /ComfyUI/custom_nodes
RUN cd /ComfyUI/custom_nodes && git clone https://github.com/princepainter/ComfyUI-PainterI2V.git
 && if [ -f /ComfyUI/custom_nodes/ComfyUI-PainterI2V/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/ComfyUI-PainterI2V/requirements.txt; fi
RUN cd /ComfyUI/custom_nodes && git clone https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git
 && if [ -f /ComfyUI/custom_nodes/ComfyUI-WanMoeKSampler/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/ComfyUI-WanMoeKSampler/requirements.txt; fi
RUN cd /ComfyUI/custom_nodes && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
 && if [ -f /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/ComfyUI-VideoHelperSuite/requirements.txt; fi
RUN cd /ComfyUI/custom_nodes && git clone https://github.com/rgthree/rgthree-comfy.git
 && if [ -f /ComfyUI/custom_nodes/rgthree-comfy/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/rgthree-comfy/requirements.txt; fi
RUN cd /ComfyUI/custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
 && if [ -f /ComfyUI/custom_nodes/ComfyUI-Impact-Pack/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/ComfyUI-Impact-Pack/requirements.txt; fi
RUN cd /ComfyUI/custom_nodes && git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git
 && if [ -f /ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt ]; then pip install -r /ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt; fi
COPY start.sh /start.sh
RUN chmod +x /start.sh
EXPOSE 8188
CMD ["/start.sh"]
