#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/venv/bin:$PATH"
ts(){ date +"%Y-%m-%dT%H:%M:%S"; }
log(){ echo "$(ts) - $*"; }
COMFY_DIR="/workspace/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
LORA_DIR="$COMFY_DIR/models/loras"
DIFFUSION_DIR="$COMFY_DIR/models/diffusion_models"
CLIP_DIR="$COMFY_DIR/models/clip"
UPSCALE_DIR="$COMFY_DIR/models/upscale_models"
export GIT_TERMINAL_PROMPT=0
mkdir -p /workspace/.cache/pip /workspace/.cache/torch /workspace/.cache/huggingface
export PIP_CACHE_DIR="/workspace/.cache/pip"
export TORCH_HOME="/workspace/.cache/torch"
export HF_HOME="/workspace/.cache/huggingface"
declare -a NODES_REQUIRED=("ComfyUI-KJNodes|https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-WanVideoWrapper|https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "ComfyUI-WanMoeKSampler|https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git" "ComfyUI-PainterI2V|https://github.com/princepainter/ComfyUI-PainterI2V.git" "ComfyUI-FBCNN|https://github.com/Miosp/ComfyUI-FBCNN.git")
declare -a NODES_OPTIONAL=("ComfyUI-Impact-Pack|https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "ComfyUI-VideoHelperSuite|https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "rgthree-comfy|https://github.com/rgthree/rgthree-comfy.git" "was-node-suite-comfyui|https://github.com/WASasquatch/was-node-suite-comfyui.git" "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git" "ComfyUI_LayerStyle|https://github.com/chflame163/ComfyUI_LayerStyle.git" "ComfyUI_LayerStyle_Advance|https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git" "ComfyLiterals|https://github.com/MNeMoNiCuZ/ComfyLiterals.git" "masquerade-nodes-comfyui|https://github.com/BadCafeCode/masquerade-nodes-comfyui.git" "ComfyUI-Easy-Use|https://github.com/yolain/ComfyUI-Easy-Use.git" "ComfyUI-TeaCache|https://github.com/kijai/ComfyUI-TeaCache.git" "ComfyUI_essentials|https://github.com/cubiq/ComfyUI_essentials.git" "cg-use-everywhere|https://github.com/chrisgoringe/cg-use-everywhere.git" "cg-image-picker|https://github.com/chrisgoringe/cg-image-picker.git" "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" "ComfyUI_Comfyroll_CustomNodes|https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git" "ComfyUI_JPS-Nodes|https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git" "ComfyUI-Frame-Interpolation|https://github.com/Kosinkadink/ComfyUI-Frame-Interpolation.git")
declare -a LORAS=("i2v_lightx2v_high_noise_model.safetensors|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/high_noise_model.safetensors" "i2v_lightx2v_low_noise_model.safetensors|https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/low_noise_model.safetensors")
declare -a MODELS_HTTP=("Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors|$DIFFUSION_DIR" "Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors|$DIFFUSION_DIR" "nsfw_wan_umt5-xxl_fp8_scaled.safetensors|https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors|$CLIP_DIR")
declare -a GDOWN_FILES=("1xSkinContrast-SuperUltraCompact.pth|1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV|$UPSCALE_DIR" "Instagirlv2.5-LOW.safetensors|1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF|$LORA_DIR" "Instagirlv2.5-HIGH.safetensors|1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0|$LORA_DIR")
declare -a CIVITAI_LORAS=("boobiefixer_high.safetensors|2312759" "boobiefixer_low.safetensors|2312689" "penis_fixer_high.safetensors|2284083" "penis_fixer_low.safetensors|2284089" "nsfwsks_high.safetensors|2073605" "nsfwsks_low.safetensors|2083303" "DR34ML4Y_nsfw_low.safetensors|2190476" "DR34ML4Y_nsfw_high.safetensors|2176505" "pussy_asshole_low.safetensors|2496721" "pussy_asshole_high.safetensors|2496754")
log "🚀 Validating ComfyUI installation..."
if [ ! -d "$COMFY_DIR" ] || [ -z "$(ls -A "$COMFY_DIR" 2>/dev/null || true)" ]; then log "📥 Initializing ComfyUI from Docker image..."; mkdir -p "$COMFY_DIR"; cp -a /ComfyUI/. "$COMFY_DIR"/; else log "✅ ComfyUI found in /workspace"; fi
mkdir -p "$CUSTOM_NODES" "$LORA_DIR" "$DIFFUSION_DIR" "$CLIP_DIR" "$UPSCALE_DIR"
ensure_repo(){ local name="$1"; local url="$2"; local path="$CUSTOM_NODES/$name"; if [ -d "$path/.git" ]; then local cur; cur="$(git -C "$path" remote get-url origin 2>/dev/null || true)"; if [ "$cur" != "$url" ]; then rm -rf "$path"; fi; fi; if [ ! -d "$path" ]; then log "   Cloning: $name"; if [ "$name" = "ComfyUI_UltimateSDUpscale" ]; then git clone --recursive "$url" "$path" >/dev/null 2>&1 || true; else git clone "$url" "$path" >/dev/null 2>&1 || true; fi; fi; }
install_node_bits(){ local path="$1"; if [ -f "$path/requirements.txt" ]; then local tmp; tmp="$(mktemp)"; grep -vE '^(torch|torchvision|torchaudio|triton|sageattention|xformers)([<=> ].*)?$' "$path/requirements.txt" > "$tmp" || true; if [ -s "$tmp" ]; then python -m pip install -r "$tmp" >/dev/null 2>&1 || true; fi; rm -f "$tmp"; fi; if [ -f "$path/install.py" ]; then python "$path/install.py" >/dev/null 2>&1 || true; fi; }
log "🧩 Checking Custom Nodes..."
for entry in "${NODES_REQUIRED[@]}" "${NODES_OPTIONAL[@]}"; do IFS='|' read -r name url <<<"$entry"; ensure_repo "$name" "$url"; done
for d in "$CUSTOM_NODES"/*; do [ -d "$d" ] && install_node_bits "$d"; done
log "✅ Custom Nodes Ready"
download_http(){ local name="$1"; local url="$2"; local dir="$3"; mkdir -p "$dir"; local path="$dir/$name"; if [ -f "$path" ]; then log "   Exists: $name"; else log "   Downloading: $name"; aria2c -c -x 16 -s 16 -k 1M -q -o "$name" -d "$dir" "$url" || (curl -L --retry 5 --retry-delay 2 -o "$path" "$url" || true); fi; }
log "⬇️  Checking/Downloading base LoRAs..."
for entry in "${LORAS[@]}"; do IFS='|' read -r name url <<<"$entry"; download_http "$name" "$url" "$LORA_DIR"; done
log "⬇️  Checking/Downloading Remix + UMT5 assets..."
for entry in "${MODELS_HTTP[@]}"; do IFS='|' read -r name url dir <<<"$entry"; download_http "$name" "$url" "$dir"; done
log "⬇️  Checking/Downloading Google Drive assets..."
for entry in "${GDOWN_FILES[@]}"; do IFS='|' read -r name gid dir <<<"$entry"; mkdir -p "$dir"; if [ -f "$dir/$name" ]; then log "   Exists: $name"; else log "   Downloading: $name"; gdown --id "$gid" -O "$dir/$name" >/dev/null 2>&1 || true; fi; done
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
if [ -n "$CIVITAI_TOKEN" ]; then log "⬇️  Checking/Downloading Civitai LoRAs..."; for entry in "${CIVITAI_LORAS[@]}"; do IFS='|' read -r name model_id <<<"$entry"; if [ -f "$LORA_DIR/$name" ]; then log "   Exists: $name"; else log "   Downloading: $name"; curl -L --retry 5 --retry-delay 2 -H "Authorization: Bearer ${CIVITAI_TOKEN}" "https://civitai.com/api/download/models/${model_id}" -o "$LORA_DIR/$name" >/dev/null 2>&1 || true; fi; done; else log "ℹ️  CIVITAI_TOKEN not set, skipping Civitai LoRAs"; fi
if [ -d "$CUSTOM_NODES/ComfyLiterals/web" ]; then mkdir -p "$COMFY_DIR/web/extensions"; if [ ! -e "$COMFY_DIR/web/extensions/ComfyLiterals" ]; then ln -s "$CUSTOM_NODES/ComfyLiterals/web" "$COMFY_DIR/web/extensions/ComfyLiterals" || true; fi; fi
log "🚀 Starting ComfyUI on port 8188..."
cd "$COMFY_DIR"
exec python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
