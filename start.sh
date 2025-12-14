#!/usr/bin/env bash
set -e

########################
# CONFIG
########################
VENV_DIR="/workspace/venv"
COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
BOOT_SENTINEL="/workspace/.bootstrapped"
CLONE_JOBS="${CLONE_JOBS:-8}"

########################
# Helpers
########################
log() { echo "[$(date +%H:%M:%S)] $1"; }

clone_repo() {
  local name="$1" url="$2" dest="$3"
  if [ -d "$dest/.git" ]; then
    log "✅ Node exists: $name"
  else
    log "⬇️ Cloning node: $name"
    git clone --depth=1 "$url" "$dest"
    log "✅ Cloned: $name"
  fi
}

install_requirements_filtered() {
  sed '/opencv-python/d;/torch/d;/torchvision/d;/torchaudio/d' "$1" \
  | xargs -r pip install
}

aria_get() {
  local url="$1" out="$2"
  [ -f "$out" ] || aria2c -x 16 -s 16 -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
}

########################
# BOOTSTRAP
########################
if [ ! -f "$BOOT_SENTINEL" ]; then
  log "🧱 First-time bootstrap starting"

  python -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip

  log "📦 Cloning ComfyUI"
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
  pip install -r "$COMFY_DIR/requirements.txt"

  mkdir -p "$CUSTOM_NODES"

  ########################
  # Required repos
  ########################
  REPOS=(
    "ComfyUI-KJNodes|https://github.com/kijai/ComfyUI-KJNodes.git"
    "ComfyUI-WanVideoWrapper|https://github.com/Hearmeman24/comfyui-wan.git"
    "ComfyUI-FBCNN|https://github.com/Miosp/ComfyUI-FBCNN.git"
  )

  ########################
  # Optional repos (your list)
  ########################
  OPTIONAL_REPOS=(
    "ComfyUI-Impact-Pack|https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "ComfyUI-VideoHelperSuite|https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "rgthree-comfy|https://github.com/rgthree/rgthree-comfy.git"
    "was-node-suite-comfyui|https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    "ComfyUI_LayerStyle|https://github.com/chflame163/ComfyUI_LayerStyle.git"
    "ComfyUI_LayerStyle_Advance|https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git"
    "ComfyLiterals|https://github.com/MNeMoNiCuZ/ComfyLiterals.git"
    "masquerade-nodes-comfyui|https://github.com/BadCafeCode/masquerade-nodes-comfyui.git"
    "ComfyUI-Easy-Use|https://github.com/yolain/ComfyUI-Easy-Use.git"
    "ComfyUI-TeaCache|https://github.com/kijai/ComfyUI-TeaCache.git"
    "ComfyUI_essentials|https://github.com/cubiq/ComfyUI_essentials.git"
    "cg-use-everywhere|https://github.com/chrisgoringe/cg-use-everywhere.git"
    "cg-image-picker|https://github.com/chrisgoringe/cg-image-picker.git"
  )

  ########################
  # Clone required (fail hard)
  ########################
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r name url <<<"$entry"
    clone_repo "$name" "$url" "$CUSTOM_NODES/$name"
  done

  ########################
  # Clone optional (never fail)
  ########################
  for entry in "${OPTIONAL_REPOS[@]}"; do
    IFS='|' read -r name url <<<"$entry"
    clone_repo "$name" "$url" "$CUSTOM_NODES/$name" || true
  done

  ########################
  # Install node requirements (filtered)
  ########################
  log "📦 Installing node requirements"
  find "$CUSTOM_NODES" -name requirements.txt | while read -r req; do
    install_requirements_filtered "$req" || true
  done

  ########################
  # Fix ComfyLiterals web extension
  ########################
  if [ -d "$CUSTOM_NODES/ComfyLiterals/web" ]; then
    mkdir -p "$COMFY_DIR/web/extensions"
    ln -sf "$CUSTOM_NODES/ComfyLiterals/web" "$COMFY_DIR/web/extensions/ComfyLiterals"
    log "✅ Linked ComfyLiterals web extension"
  fi

  ########################
  # Lightning LoRAs (fixes validation errors)
  ########################
  LORA_DIR="$COMFY_DIR/models/loras"
  mkdir -p "$LORA_DIR"
  BASE="https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1"
  aria_get "$BASE/high_noise_model.safetensors" "$LORA_DIR/i2v_lightx2v_high_noise_model.safetensors"
  aria_get "$BASE/low_noise_model.safetensors"  "$LORA_DIR/i2v_lightx2v_low_noise_model.safetensors"

  touch "$BOOT_SENTINEL"
  log "✅ Bootstrap complete 🎉"
else
  log "⚡ Fast start (bootstrap skipped)"
  source "$VENV_DIR/bin/activate"
fi

########################
# START COMFYUI
########################
cd "$COMFY_DIR"
exec python main.py --listen 0.0.0.0 --port 8188
