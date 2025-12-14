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
if [ ! -d "$COMFY_DIR" ] || [ -z "$(ls -A "$COMFY_DIR" 2>/dev/null || true)" ]; then mkdir -p "$COMFY_DIR"; cp -a /ComfyUI/. "$COMFY_DIR"/; fi
python -m pip install --no-cache-dir -U pip setuptools wheel packaging gdown
desired_torch="2.8.0"
cur_torch="$(python -c "import torch; print(torch.__version__.split('+')[0])" 2>/dev/null || true)"
if [[ "$cur_torch" != "$desired_torch" ]]; then log "Reinstalling torch stack to ${desired_torch} (cu128)"; python -m pip uninstall -y torch torchvision torchaudio || true; python -m pip install --no-cache-dir "torch==2.8.0" "torchvision==0.23.0" "torchaudio==2.8.0" --index-url https://download.pytorch.org/whl/cu128 --extra-index-url https://pypi.org/simple || python -m pip install --no-cache-dir --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128 --extra-index-url https://pypi.org/simple; fi
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"
python -m pip freeze | grep -E "^(torch|torchvision|torchaudio)" > /opt/torch-constraint.txt || true
export PIP_CONSTRAINT=/opt/torch-constraint.txt
python -m pip install --no-cache-dir --upgrade --force-reinstall "numpy==1.26.4" "cupy-cuda12x==12.3.0" "mediapipe==0.10.21" || true
python -m pip install --no-cache-dir --upgrade "comfyui-frontend-package>=1.33.13" || true
python -m pip install --no-cache-dir --upgrade opencv-contrib-python boto3 tqdm imageio imageio-ffmpeg scikit-image onnx onnxruntime-gpu || true
if ! python -c "import sageattention" >/dev/null 2>&1; then log "Building SageAttention from source (GPU host)"; rm -rf /tmp/SageAttention; git clone --depth=1 https://github.com/thu-ml/SageAttention.git /tmp/SageAttention; export EXT_PARALLEL="${EXT_PARALLEL:-4}" NVCC_APPEND_FLAGS="${NVCC_APPEND_FLAGS:---threads 8}" MAX_JOBS="${MAX_JOBS:-32}" TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-8.6;8.9;9.0;12.0}"; (cd /tmp/SageAttention && python -m pip install --no-cache-dir -v .) || true; python -c "import sageattention" >/dev/null 2>&1 || log "SageAttention build failed (non-fatal)"; fi
declare -a NODES_REQUIRED=( "ComfyUI-KJNodes|https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-WanVideoWrapper|https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "ComfyUI-WanMoeKSampler|https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git" "ComfyUI-PainterI2V|https://github.com/princepainter/ComfyUI-PainterI2V.git" "ComfyUI-FBCNN|https://github.com/Miosp/ComfyUI-FBCNN.git" )
declare -a NODES_OPTIONAL=( "ComfyUI-Impact-Pack|https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "ComfyUI-VideoHelperSuite|https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "rgthree-comfy|https://github.com/rgthree/rgthree-comfy.git" "was-node-suite-comfyui|https://github.com/WASasquatch/was-node-suite-comfyui.git" "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git" "ComfyUI_LayerStyle|https://github.com/chflame163/ComfyUI_LayerStyle.git" "ComfyUI_LayerStyle_Advance|https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git" "ComfyLiterals|https://github.com/MNeMoNiCuZ/ComfyLiterals.git" "masquerade-nodes-comfyui|https://github.com/BadCafeCode/masquerade-nodes-comfyui.git" "ComfyUI-Easy-Use|https://github.com/yolain/ComfyUI-Easy-Use.git" "ComfyUI-TeaCache|https://github.com/welltop-cn/ComfyUI-TeaCache.git" "ComfyUI_essentials|https://github.com/cubiq/ComfyUI_essentials.git" "cg-use-everywhere|https://github.com/chrisgoringe/cg-use-everywhere.git" "cg-image-picker|https://github.com/chrisgoringe/cg-image-picker.git" "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" "ComfyUI_Comfyroll_CustomNodes|https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git" "ComfyUI_JPS-Nodes|https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git" "ComfyUI-Frame-Interpolation|https://github.com/Kosinkadink/ComfyUI-Frame-Interpolation.git" )
mkdir -p "$CUSTOM_NODES"
force_clone(){ local name="$1"; local url="$2"; rm -rf "$CUSTOM_NODES/$name"; git clone --depth=1 --recursive "$url" "$CUSTOM_NODES/$name" || true; }
clone_once(){ local name="$1"; local url="$2"; local path="$CUSTOM_NODES/$name"; if [ -d "$path" ]; then return; fi; git clone --depth=1 --recursive "$url" "$path" || true; }
log "Syncing required nodes"
force_clone "ComfyUI-PainterI2V" "https://github.com/princepainter/ComfyUI-PainterI2V.git"
force_clone "ComfyUI-WanMoeKSampler" "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
for entry in "${NODES_REQUIRED[@]}"; do IFS='|' read -r name url <<<"$entry"; if [[ "$name" != "ComfyUI-PainterI2V" && "$name" != "ComfyUI-WanMoeKSampler" ]]; then clone_once "$name" "$url"; fi; done
for entry in "${NODES_OPTIONAL[@]}"; do IFS='|' read -r name url <<<"$entry"; clone_once "$name" "$url"; done
log "Installing node requirements"
find "$CUSTOM_NODES" -maxdepth 2 -name requirements.txt | while read -r req; do grep -vE "^(torch|torchvision|torchaudio|sageattention)([<=>].*)?$" "$req" > "${req}.clean" || true; if [ -s "${req}.clean" ]; then python -m pip install --no-cache-dir --upgrade -r "${req}.clean" --extra-index-url https://pypi.org/simple || true; fi; rm -f "${req}.clean"; done
mkdir -p "$LORA_DIR" "$DIFF_DIR" "$CLIP_DIR" "$UPSCALE_DIR"
download(){ local url="$1"; local out="$2"; local dir; dir="$(dirname "$out")"; mkdir -p "$dir"; if [ -f "$out" ]; then return; fi; aria2c -c -x 16 -s 16 -k 1M -q -d "$dir" -o "$(basename "$out")" "$url" || curl -L --retry 8 --retry-connrefused --retry-delay 2 -o "$out" "$url" || true; }
download "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/high_noise_model.safetensors" "$LORA_DIR/i2v_lightx2v_high_noise_model.safetensors"
download "https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/low_noise_model.safetensors" "$LORA_DIR/i2v_lightx2v_low_noise_model.safetensors"
download "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
download "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
download "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$CLIP_DIR/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
if [ ! -f "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth" ]; then gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth" || true; fi
civitai_get(){ local model_id="$1"; local out="$2"; local tok="${CIVITAI_TOKEN:-${CIVITAI_API_TOKEN:-}}"; if [ -f "$out" ]; then return; fi; if [ -z "$tok" ]; then log "Civitai token not set, skipping $(basename "$out")"; return; fi; curl -L --retry 8 --retry-connrefused --retry-delay 2 -H "Authorization: Bearer ${tok}" "https://civitai.com/api/download/models/${model_id}" -o "$out" || true; curl -s --max-time 1 http://127.0.0.1:8188/reload-loras >/dev/null 2>&1 || true; }
civitai_get "2312759" "$LORA_DIR/boobiefixer_high.safetensors"
civitai_get "2312689" "$LORA_DIR/boobiefixer_low.safetensors"
civitai_get "2284083" "$LORA_DIR/penis_fixer_high.safetensors"
civitai_get "2284089" "$LORA_DIR/penis_fixer_low.safetensors"
if [ ! -f "$LORA_DIR/Instagirlv2.5-LOW.safetensors" ]; then gdown --id 1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF -O "$LORA_DIR/Instagirlv2.5-LOW.safetensors" || true; fi
if [ ! -f "$LORA_DIR/Instagirlv2.5-HIGH.safetensors" ]; then gdown --id 1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0 -O "$LORA_DIR/Instagirlv2.5-HIGH.safetensors" || true; fi
civitai_get "2073605" "$LORA_DIR/nsfwsks_high.safetensors"
civitai_get "2083303" "$LORA_DIR/nsfwsks_low.safetensors"
civitai_get "2190476" "$LORA_DIR/DR34ML4Y_nsfw_low.safetensors"
civitai_get "2176505" "$LORA_DIR/DR34ML4Y_nsfw_high.safetensors"
civitai_get "2496721" "$LORA_DIR/pussy_asshole_low.safetensors"
civitai_get "2496754" "$LORA_DIR/pussy_asshole_high.safetensors"
if [ -d "$CUSTOM_NODES/ComfyLiterals/web" ]; then mkdir -p "$COMFY_DIR/web/extensions"; if [ ! -e "$COMFY_DIR/web/extensions/ComfyLiterals" ]; then ln -s "$CUSTOM_NODES/ComfyLiterals/web" "$COMFY_DIR/web/extensions/ComfyLiterals" || true; fi; fi
log "Starting ComfyUI"
cd "$COMFY_DIR"
exec python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
