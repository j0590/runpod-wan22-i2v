#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/venv/bin:$PATH"
export WORKDIR=/workspace/ComfyUI
export COMFYUI_ARGS="${COMFYUI_ARGS:---listen 0.0.0.0 --port 8188}"
export UPDATE_COMFYUI="${UPDATE_COMFYUI:-false}"
export INSTALL_CUSTOM_NODES="${INSTALL_CUSTOM_NODES:-true}"
export UPDATE_CUSTOM_NODES="${UPDATE_CUSTOM_NODES:-false}"
export INSTALL_NODE_DEPS="${INSTALL_NODE_DEPS:-true}"
export DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-true}"
ts(){ date +"%H:%M:%S"; }
log(){ echo "[$(ts)] $1"; }
fail(){ log "💥 $1"; exit 1; }
trap 'fail "Startup failed at line $LINENO"' ERR
log "🚀 Boot starting"
mkdir -p /workspace
gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || true)"
if [ -n "$gpu_name" ]; then log "🧠 GPU detected: ${gpu_name}"; else log "⚠️ No GPU detected (this is unusual on RunPod GPU)"; fi
if nvidia-smi >/dev/null 2>&1; then
  if echo "$gpu_name" | grep -qi "5090"; then
    log "🔥 RTX 5090 detected → installing pinned CUDA torch stack"
    pip uninstall -y torch torchvision torchaudio || true
    pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
    pip freeze | grep -E "^(torch|torchvision|torchaudio)" | tee /torch-constraint.txt >/dev/null
    python -m pip install "numpy==1.26.4" "cupy-cuda12x==12.3.0" "mediapipe==0.10.21" --upgrade --force-reinstall
    python -m pip install "comfyui-frontend-package>=1.33.13" --upgrade
    log "✅ Torch stack installed for RTX 5090"
  else
    log "🔥 Installing CUDA torch (cu128)"
    pip uninstall -y torch torchvision torchaudio || true
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    python -m pip install "comfyui-frontend-package>=1.33.13" --upgrade
    log "✅ CUDA torch installed"
  fi
fi
if [ ! -d "$WORKDIR" ]; then log "📦 Cloning ComfyUI into $WORKDIR"; git clone https://github.com/comfyanonymous/ComfyUI.git "$WORKDIR"; log "✅ ComfyUI cloned"; else if [ "$UPDATE_COMFYUI" = "true" ]; then log "🔄 Updating ComfyUI"; cd "$WORKDIR" && git pull; log "✅ ComfyUI updated"; fi; fi
cd "$WORKDIR"
if [ ! -f "$WORKDIR/.comfy_requirements_done" ] || [ "$UPDATE_COMFYUI" = "true" ]; then log "📦 Installing ComfyUI requirements"; pip install -r requirements.txt; touch "$WORKDIR/.comfy_requirements_done"; log "✅ ComfyUI requirements done"; else log "✅ ComfyUI requirements already done"; fi
mkdir -p "$WORKDIR/custom_nodes" "$WORKDIR/models/diffusion_models" "$WORKDIR/models/clip" "$WORKDIR/models/vae" "$WORKDIR/models/loras" "$WORKDIR/models/upscale_models" "$WORKDIR/user/default/workflows"
if [ -f /moeksampler.json ]; then cp -f /moeksampler.json "$WORKDIR/user/default/workflows/moeksampler.json"; log "✅ Workflow installed: moeksampler.json"; fi
if [ "$INSTALL_CUSTOM_NODES" = "true" ]; then
  log "🧩 Custom nodes setup starting"
  cd "$WORKDIR/custom_nodes"
  repos=(https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git https://github.com/kijai/ComfyUI-KJNodes.git https://github.com/rgthree/rgthree-comfy.git https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git https://github.com/Jordach/comfy-plasma.git https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git https://github.com/bash-j/mikey_nodes.git https://github.com/ltdrdata/ComfyUI-Impact-Pack.git https://github.com/Fannovel16/comfyui_controlnet_aux.git https://github.com/yolain/ComfyUI-Easy-Use.git https://github.com/kijai/ComfyUI-Florence2.git https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper.git https://github.com/WASasquatch/was-node-suite-comfyui.git https://github.com/theUpsider/ComfyUI-Logic.git https://github.com/cubiq/ComfyUI_essentials.git https://github.com/chrisgoringe/cg-image-picker.git https://github.com/chflame163/ComfyUI_LayerStyle.git https://github.com/chrisgoringe/cg-use-everywhere.git https://github.com/kijai/ComfyUI-segment-anything-2.git https://github.com/welltop-cn/ComfyUI-TeaCache.git https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git https://github.com/Jonseed/ComfyUI-Detail-Daemon.git https://github.com/kijai/ComfyUI-WanVideoWrapper.git https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git https://github.com/BadCafeCode/masquerade-nodes-comfyui.git https://github.com/1038lab/ComfyUI-RMBG.git https://github.com/M1kep/ComfyLiterals.git https://github.com/princepainter/ComfyUI-PainterI2V.git https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git https://github.com/ssitu/ComfyUI-FBCNN.git)
  for repo in "${repos[@]}"; do
    repo_dir=$(basename "$repo" .git)
    if [ -d "$repo_dir/.git" ]; then
      if [ "$UPDATE_CUSTOM_NODES" = "true" ]; then log "🔄 Updating node: $repo_dir"; cd "$repo_dir" && git pull && cd ..; log "✅ Updated node: $repo_dir"; else log "✅ Node present: $repo_dir"; fi
    else
      log "⬇️ Cloning node: $repo_dir"
      if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then git clone --recursive "$repo"; else git clone "$repo"; fi
      log "✅ Cloned node: $repo_dir"
    fi
    if [ "$INSTALL_NODE_DEPS" = "true" ]; then
      if [ -f "$repo_dir/requirements.txt" ]; then log "📦 Installing deps: $repo_dir"; pip install -r "$repo_dir/requirements.txt"; log "✅ Deps installed: $repo_dir"; fi
      if [ -f "$repo_dir/install.py" ]; then log "⚙️ Running install.py: $repo_dir"; python "$repo_dir/install.py"; log "✅ install.py done: $repo_dir"; fi
    fi
  done
  log "✅ Custom nodes setup complete"
else
  log "⏭️ Skipping custom nodes (INSTALL_CUSTOM_NODES=false)"
fi
dl(){ url="$1"; out="$2"; if [ -f "$out" ]; then log "✅ File exists: $(basename "$out")"; else log "⬇️ Downloading: $(basename "$out")"; aria2c -x16 -s16 -k1M -o "$(basename "$out")" -d "$(dirname "$out")" "$url"; log "✅ Downloaded: $(basename "$out")"; fi }
dltoken(){ url="$1"; out="$2"; hdr="$3"; if [ -f "$out" ]; then log "✅ File exists: $(basename "$out")"; else log "⬇️ Downloading: $(basename "$out")"; curl -L -H "$hdr" "$url" -o "$out"; log "✅ Downloaded: $(basename "$out")"; fi }
if [ "$DOWNLOAD_MODELS" = "true" ]; then
  log "📥 Model downloads starting"
  dl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$WORKDIR/models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
  dl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$WORKDIR/models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
  dl "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$WORKDIR/models/clip/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
  dl "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/3902f61b9647e65d4de4fb5febad34ca0e4dc5c8/split_files/vae/wan_2.1_vae.safetensors" "$WORKDIR/models/vae/wan_2.1_vae.safetensors"
  if [ ! -f "$WORKDIR/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth" ]; then log "⬇️ Downloading upscaler: 1xSkinContrast"; gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$WORKDIR/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth"; log "✅ Downloaded upscaler"; else log "✅ Upscaler exists"; fi
  if [ -n "${civitai_token:-}" ]; then
    log "🔐 Civitai token present → downloading Civitai LoRAs"
    dltoken "https://civitai.com/api/download/models/2312759" "$WORKDIR/models/loras/boobiefixer_high.safetensors" "Authorization: Bearer ${civitai_token}"
    dltoken "https://civitai.com/api/download/models/2312689" "$WORKDIR/models/loras/boobiefixer_low.safetensors" "Authorization: Bearer ${civitai_token}"
    dltoken "https://civitai.com/api/download/models/2284083" "$WORKDIR/models/loras/penis_fixer_high.safetensors" "Authorization: Bearer ${civitai_token}"
    dltoken "https://civitai.com/api/download/models/2284089" "$WORKDIR/models/loras/penis_fixer_low.safetensors" "Authorization: Bearer ${civitai_token}"
    dltoken "https://civitai.com/api/download/models/2073605" "$WORKDIR/models/loras/nsfwsks_high.safetensors" "Authorization: Bearer ${civitai_token}"
    dltoken "https://civitai.com/api/download/models/2083303" "$WORKDIR/models/loras/nsfwsks_low.safetensors" "Authorization: Bearer ${civitai_token}"
    dltoken "https://civitai.com/api/download/models/2012120" "$WORKDIR/models/loras/female_genitals_LOW.safetensors" "Authorization: Bearer ${civitai_token}"
    log "✅ Civitai LoRAs downloaded"
  else
    log "⚠️ civitai_token not set → skipping Civitai LoRAs"
  fi
  if [ ! -f "$WORKDIR/models/loras/Instagirlv2.5-LOW.safetensors" ]; then log "⬇️ Downloading Instagirl LOW"; gdown --id 1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF -O "$WORKDIR/models/loras/Instagirlv2.5-LOW.safetensors"; log "✅ Instagirl LOW downloaded"; else log "✅ Instagirl LOW exists"; fi
  if [ ! -f "$WORKDIR/models/loras/Instagirlv2.5-HIGH.safetensors" ]; then log "⬇️ Downloading Instagirl HIGH"; gdown --id 1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0 -O "$WORKDIR/models/loras/Instagirlv2.5-HIGH.safetensors"; log "✅ Instagirl HIGH downloaded"; else log "✅ Instagirl HIGH exists"; fi
  log "✅ Model downloads complete"
else
  log "⏭️ Skipping downloads (DOWNLOAD_MODELS=false)"
fi
log "🌐 Starting ComfyUI on 8188"
cd "$WORKDIR"
exec python main.py $COMFYUI_ARGS
