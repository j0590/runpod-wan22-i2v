#!/usr/bin/env bash
# Optimized start.sh for RunPod + Wan2.2 I2V + RTX 5090
set -euo pipefail

# Ensure we use the venv created in Dockerfile
export PATH="/opt/venv/bin:$PATH"

# --- CONFIGURATION (Add/Remove items here) ---

# Required Custom Nodes (Must have for your workflow)
declare -a NODES_REQUIRED=(
  "ComfyUI-KJNodes|https://github.com/kijai/ComfyUI-KJNodes.git"
  "ComfyUI-WanVideoWrapper|https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
  "ComfyUI-WanMoeKSampler|https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
  "ComfyUI-PainterI2V|https://github.com/princepainter/ComfyUI-PainterI2V.git"
  "ComfyUI-FBCNN|https://github.com/Miosp/ComfyUI-FBCNN.git"
)

# Optional Custom Nodes (Nice to have, your previous list)
declare -a NODES_OPTIONAL=(
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
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
  "ComfyUI_Comfyroll_CustomNodes|https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
  "ComfyUI_JPS-Nodes|https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git"
  "ComfyUI-Frame-Interpolation|https://github.com/Kosinkadink/ComfyUI-Frame-Interpolation.git"
)

# LoRAs to Download (Wan2.2 Lightning)
# Syntax: "Filename|URL"
declare -a LORAS=(
  "i2v_lightx2v_high_noise_model.safetensors|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/high_noise_model.safetensors"
  "i2v_lightx2v_low_noise_model.safetensors|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/low_noise_model.safetensors"
)

# --- END CONFIGURATION ---

ts() { date +"%Y-%m-%dT%H:%M:%S"; }
log() { echo "$(ts) - $*"; }

COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
LORA_DIR="$COMFY_DIR/models/loras"

# Speed up git for automations
export GIT_TERMINAL_PROMPT=0

# Ensure persistent cache dirs exist
mkdir -p /workspace/.cache/pip /workspace/.cache/torch /workspace/.cache/huggingface
export PIP_CACHE_DIR="/workspace/.cache/pip"
export TORCH_HOME="/workspace/.cache/torch"
export HF_HOME="/workspace/.cache/huggingface"

# -------------------------------------------------------------------------
# 1. ComfyUI Setup
# -------------------------------------------------------------------------
log "🚀 Validating ComfyUI installation..."
if [ ! -d "$COMFY_DIR" ] || [ -z "$(ls -A "$COMFY_DIR")" ]; then
    log "📥 Initializing ComfyUI from Docker image..."
    # Copy from the image version (fast) to the volume
    cp -a /ComfyUI/. "$COMFY_DIR"/
else
    log "✅ ComfyUI found in /workspace"
    # Optional: Update it?
    # git -C "$COMFY_DIR" pull || true
fi

# -------------------------------------------------------------------------
# 2. Custom Nodes Setup
# -------------------------------------------------------------------------
mkdir -p "$CUSTOM_NODES"

clone_repo() {
    local name="$1"
    local url="$2"
    local path="$CUSTOM_NODES/$name"

    if [ -d "$path" ]; then
        log "   Exists: $name"
        return
    fi
    log "   Cloning: $name"
    # Use background process for speed, managed by caller
    git clone --depth=1 --recursive "$url" "$path" >/dev/null 2>&1 || log "❌ Setup Failed: $name"
}

log "🧩 Checking Custom Nodes..."

# Launch downloads in background
pids=()
for entry in "${NODES_REQUIRED[@]}" "${NODES_OPTIONAL[@]}"; do
    IFS='|' read -r name url <<<"$entry"
    clone_repo "$name" "$url" &
    pids+=($!)
done

# Wait for all git clones
for pid in "${pids[@]}"; do
    wait "$pid" || true
done

log "✅ Custom Nodes Checked/Cloned"

# -------------------------------------------------------------------------
# 3. Dependencies (Pip)
# -------------------------------------------------------------------------
# We already installed heavy deps in Dockerfile.
# Just check node-specific requirements.txt
log "📦 Checking Node Requirements..."

# Find all requirements.txt in custom_nodes depth 2
# Filter out conflicting torch/opencv installs that break the environment
find "$CUSTOM_NODES" -maxdepth 2 -name requirements.txt | while read req_file; do
    # Only install if not already satisfied (pip install is somewhat slow to check, but necessary)
    # We strip lines we KNOW are bad or already handled
    grep -vE "torch|torchvision|torchaudio|opencv-python|opencv-python-headless|sageattention" "$req_file" > "${req_file}.clean"
    
    if [ -s "${req_file}.clean" ]; then
        pip install -r "${req_file}.clean" --no-deps >/dev/null 2>&1 || true
    fi
    rm "${req_file}.clean"
done

# Fix for LayerStyle (requires opencv-contrib, pre-installed in Docker, but ensure no conflict)
# This is handled by pre-installing opencv-contrib-python in Dockerfile.

# -------------------------------------------------------------------------
# 4. LoRAs / Models
# -------------------------------------------------------------------------
mkdir -p "$LORA_DIR"

download_file() {
    local name="$1"
    local url="$2"
    local path="$LORA_DIR/$name"
    
    if [ -f "$path" ]; then
        log "   Exists: $name"
    else
        log "   Downloading: $name"
        aria2c -c -x 16 -s 16 -k 1M -q -o "$name" -d "$LORA_DIR" "$url" || log "❌ Failed: $name"
    fi
}

log "⬇️  Checking/Downloading LoRAs..."
for entry in "${LORAS[@]}"; do
    IFS='|' read -r name url <<<"$entry"
    download_file "$name" "$url"
done

# -------------------------------------------------------------------------
# 5. Fixes & Tweaks
# -------------------------------------------------------------------------

# Fix ComfyLiterals web extension link
if [ -d "$CUSTOM_NODES/ComfyLiterals/web" ]; then
  mkdir -p "$COMFY_DIR/web/extensions"
  if [ ! -e "$COMFY_DIR/web/extensions/ComfyLiterals" ]; then
    ln -s "$CUSTOM_NODES/ComfyLiterals/web" "$COMFY_DIR/web/extensions/ComfyLiterals" || true
  fi
fi

# -------------------------------------------------------------------------
# 6. Launch
# -------------------------------------------------------------------------
log "🚀 Starting ComfyUI on port 8188..."
cd "$COMFY_DIR"

# Standard arguments
ARGS="--listen 0.0.0.0 --port 8188 --preview-method auto"

exec python main.py $ARGS
