FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1 PYTHONUNBUFFERED=1 CMAKE_BUILD_PARALLEL_LEVEL=8 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN apt-get update && apt-get install -y --no-install-recommends python3.12 python3.12-venv python3.12-dev python3-pip curl ffmpeg ninja-build git aria2 git-lfs wget vim ca-certificates libgl1 libglib2.0-0 build-essential gcc && ln -sf /usr/bin/python3.12 /usr/bin/python && ln -sf /usr/bin/pip3 /usr/bin/pip && python3.12 -m venv /opt/venv && /opt/venv/bin/pip install -U pip setuptools wheel packaging && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/venv/bin:$PATH"
COPY start.sh /start.sh
COPY moeksampler.json /moeksampler.json
RUN chmod +x /start.sh
EXPOSE 8188 8888
CMD ["/start.sh"]
