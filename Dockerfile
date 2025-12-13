FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    curl ffmpeg ninja-build git aria2 git-lfs wget vim \
    libgl1 libglib2.0-0 build-essential gcc ca-certificates \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && python3.12 -m venv /opt/venv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --upgrade pip setuptools wheel packaging
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
RUN pip install pyyaml gdown triton comfy-cli opencv-python

RUN /usr/bin/yes | comfy --workspace /ComfyUI install

RUN mkdir -p /ComfyUI/custom_nodes
WORKDIR /ComfyUI/custom_nodes
RUN for repo in \
    https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/rgthree/rgthree-comfy.git \
    https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    https://github.com/Jordach/comfy-plasma.git \
    https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git \
    https://github.com/bash-j/mikey_nodes.git \
    https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    https://github.com/yolain/ComfyUI-Easy-Use.git \
    https://github.com/kijai/ComfyUI-Florence2.git \
    https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper.git \
    https://github.com/WASasquatch/was-node-suite-comfyui.git \
    https://github.com/theUpsider/ComfyUI-Logic.git \
    https://github.com/cubiq/ComfyUI_essentials.git \
    https://github.com/chrisgoringe/cg-image-picker.git \
    https://github.com/chflame163/ComfyUI_LayerStyle.git \
    https://github.com/chrisgoringe/cg-use-everywhere.git \
    https://github.com/kijai/ComfyUI-segment-anything-2.git \
    https://github.com/ClownsharkBatwing/RES4LYF \
    https://github.com/welltop-cn/ComfyUI-TeaCache.git \
    https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git \
    https://github.com/Jonseed/ComfyUI-Detail-Daemon.git \
    https://github.com/kijai/ComfyUI-WanVideoWrapper.git \
    https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git \
    https://github.com/BadCafeCode/masquerade-nodes-comfyui.git \
    https://github.com/1038lab/ComfyUI-RMBG.git \
    https://github.com/M1kep/ComfyLiterals.git; \
do \
    repo_dir=$(basename "$repo" .git); \
    git clone "$repo"; \
    if [ -f "$repo_dir/requirements.txt" ]; then pip install -r "$repo_dir/requirements.txt"; fi; \
    if [ -f "$repo_dir/install.py" ]; then python "$repo_dir/install.py"; fi; \
done

COPY start.sh /start.sh
RUN chmod +x /start.sh
EXPOSE 8188
CMD ["/start.sh"]
