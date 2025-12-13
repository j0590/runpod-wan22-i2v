FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git curl wget aria2 ffmpeg python3 python3-pip python3-venv ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
RUN python3 -m pip install --upgrade pip && pip install -r /workspace/ComfyUI/requirements.txt
COPY start.sh /start.sh
RUN chmod +x /start.sh
EXPOSE 8188
CMD ["/start.sh"]
