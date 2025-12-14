#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/venv/bin:$PATH"
ts(){ date +"%Y-%m-%dT%H:%M:%S"; }
log(){ echo "$(ts) - $*"; }
COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
LORA_DIR="$COMFY_DIR/models/loras"
DIFF_DIR="$COMFY_DIR/models/diffusion_models"
CLIP_DIR="$COMFY_DIR/models/clip"
UPSCALE_DIR="$COMFY_DIR/models/upscale_models"
export GIT_TERMINAL_PROMPT=0
mkdir -p /workspace/.cache/pip /workspace/.cache/torch /workspace/.cache/huggingface
export PIP_CACHE_DIR="/workspace/.cache/pip"
export TORCH_HOME="/workspace/.cache/torch"
export HF_HOME="/workspace/.cache/huggingface"
curl_retry(){ curl -L --retry 10 --retry-delay 2 --retry-connrefused --fail "$@"; }
aria_or_curl(){ local url="$1"; local out="$2"; mkdir -p "$(dirname "$out")"; if [ -f "$out" ]; then log "   Exists: $(basename "$out")"; return; fi; log "   Downloading: $(basename "$out")"; aria2c -c -x 16 -s 16 -k 1M -q -o "$(basename "$out")" -d "$(dirname "$out")" "$url" || curl_retry -o "$out" "$url" || true; }
gdown_file(){ local id="$1"; local out="$2"; mkdir -p "$(dirname "$out")"; if [ -f "$out" ]; then log "   Exists: $(basename "$out")"; return; fi; log "   Downloading (gdrive): $(basename "$out")"; gdown --id "$id" -O "$out" >/dev/null 2>&1 || true; }
civitai_file(){ local model_id="$1"; local out="$2"; mkdir -p "$(dirname "$out")"; if [ -f "$out" ]; then log "   Exists: $(basename "$out")"; return; fi; if [ -z "${CIVITAI_TOKEN:-}" ]; then log "⚠️  CIVITAI_TOKEN not set, skipping $(basename "$out")"; return; fi; log "   Downloading (civitai): $(basename "$out")"; curl_retry -H "Authorization: Bearer ${CIVITAI_TOKEN}" "https://civitai.com/api/download/models/${model_id}" -o "$out" >/dev/null 2>&1 || true; curl -s http://127.0.0.1:8188/reload-loras >/dev/null 2>&1 || true; }
log "🚀 Ensuring ComfyUI in /workspace..."
if [ ! -d "$COMFY_DIR" ] || [ -z "$(ls -A "$COMFY_DIR" 2>/dev/null || true)" ]; then mkdir -p "$COMFY_DIR"; if [ -d "/ComfyUI/.git" ] && [ -n "$(ls -A /ComfyUI 2>/dev/null || true)" ]; then cp -a /ComfyUI/. "$COMFY_DIR"/; else /usr/bin/yes | comfy --workspace "$COMFY_DIR" install; fi; fi
mkdir -p "$CUSTOM_NODES" "$LORA_DIR" "$DIFF_DIR" "$CLIP_DIR" "$UPSCALE_DIR"
log "📦 Ensuring Torch 2.8.0 + CUDA 12.8 (cu128)..."
python - <<'PY' || true
import importlib,sys
def v(m):
  try: return importlib.import_module(m).__version__
  except Exception: return None
t=v("torch"); tv=v("torchvision"); ta=v("torchaudio")
print("installed:",t,tv,ta)
ok=(t and t.startswith("2.8.0") and tv and tv.startswith("0.23.0") and ta and ta.startswith("2.8.0"))
sys.exit(0 if ok else 1)
PY
if [ "$?" != "0" ]; then pip uninstall -y torch torchvision torchaudio >/dev/null 2>&1 || true; pip install torch==2.8.0 torchvision==0.23.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128; fi
pip freeze | grep -E "^(torch|torchvision|torchaudio)" > /workspace/torch-constraint.txt || true
export PIP_CONSTRAINT=/workspace/torch-constraint.txt
python -c "import torch; print(torch.__version__); print(torch.version.cuda)"
log "📦 Forcing known-good runtime deps..."
python -m pip install "numpy==1.26.4" "cupy-cuda12x==12.3.0" "mediapipe==0.10.21" --upgrade --force-reinstall
python -m pip install "comfyui-frontend-package>=1.33.13" --upgrade
log "🧩 Installing required custom nodes..."
cd "$CUSTOM_NODES"
rm -rf ComfyUI-PainterI2V && git clone --depth=1 https://github.com/princepainter/ComfyUI-PainterI2V.git || true
rm -rf ComfyUI-WanMoeKSampler && git clone --depth=1 https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git || true
if [ ! -d "ComfyUI-WanVideoWrapper" ]; then git clone --depth=1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git || true; fi
if [ ! -d "ComfyUI-KJNodes" ]; then git clone --depth=1 https://github.com/kijai/ComfyUI-KJNodes.git || true; fi
if [ ! -d "ComfyUI-FBCNN" ]; then git clone --depth=1 https://github.com/Miosp/ComfyUI-FBCNN.git || true; fi
log "📦 Installing node requirements (without touching Torch)..."
find "$CUSTOM_NODES" -maxdepth 2 -name requirements.txt | while read -r r; do grep -vE "^(torch|torchvision|torchaudio)([<=> ].*)?$" "$r" > "$r.clean" || true; if [ -s "$r.clean" ]; then python -m pip install -r "$r.clean" --no-deps >/dev/null 2>&1 || true; fi; rm -f "$r.clean"; done
log "⬇️  Downloading requested models/assets..."
aria_or_curl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
aria_or_curl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
aria_or_curl "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$CLIP_DIR/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
gdown_file "1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV" "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth"
gdown_file "1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF" "$LORA_DIR/Instagirlv2.5-LOW.safetensors"
gdown_file "1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0" "$LORA_DIR/Instagirlv2.5-HIGH.safetensors"
civitai_file "2312759" "$LORA_DIR/boobiefixer_high.safetensors"
civitai_file "2312689" "$LORA_DIR/boobiefixer_low.safetensors"
civitai_file "2284083" "$LORA_DIR/penis_fixer_high.safetensors"
civitai_file "2284089" "$LORA_DIR/penis_fixer_low.safetensors"
civitai_file "2073605" "$LORA_DIR/nsfwsks_high.safetensors"
civitai_file "2083303" "$LORA_DIR/nsfwsks_low.safetensors"
civitai_file "2190476" "$LORA_DIR/DR34ML4Y_nsfw_low.safetensors"
civitai_file "2176505" "$LORA_DIR/DR34ML4Y_nsfw_high.safetensors"
civitai_file "2496721" "$LORA_DIR/pussy_asshole_low.safetensors"
civitai_file "2496754" "$LORA_DIR/pussy_asshole_high.safetensors"
log "🚀 Starting ComfyUI..."
cd "$COMFY_DIR"
exec python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
