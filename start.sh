#!/usr/bin/env bash
set -u # Warn on unset variables, but don't crash on minor errors

# 1. OPTIMIZATION: Use libtcmalloc for better memory management (Critical for 14B models)
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PATH="/opt/venv/bin:$PATH"

# 2. SETUP: Define Directories
# We check if a Network Volume is attached at /workspace.
if [ -d "/workspace" ]; then
    echo "✅ Network Volume found at /workspace"
    ROOT_DIR="/workspace"
else
    echo "⚠️ No Network Volume found. Using internal storage (data will be lost on restart)."
    ROOT_DIR="/"
fi

COMFY_DIR="$ROOT_DIR/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
DIFF_DIR="$COMFY_DIR/models/diffusion_models"
LORA_DIR="$COMFY_DIR/models/loras"
CLIP_DIR="$COMFY_DIR/models/clip"
UPSCALE_DIR="$COMFY_DIR/models/upscale_models"

# 3. BUILD: Start SageAttention Build in Background (Critical for Speed)
echo "⚙️  Starting SageAttention build in background..."
(
    cd /tmp
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    # Reset to known good commit if needed, or stick to latest
    git reset --hard 68de379 
    export NVCC_APPEND_FLAGS="--threads 4"
    pip install -e .
    echo "done" > /tmp/sage_build_done
) > /tmp/sage_build.log 2>&1 &
SAGE_PID=$!

# 4. SYNC: Ensure ComfyUI Exists
if [ ! -d "$COMFY_DIR" ] || [ -z "$(ls -A "$COMFY_DIR")" ]; then
    echo "📦 Copying ComfyUI to volume..."
    cp -a /ComfyUI/. "$COMFY_DIR/"
fi

# 5. INSTALL: Custom Nodes (Merged List: Hearemen + Yours)
echo "🧩 Installing Custom Nodes..."
mkdir -p "$CUSTOM_NODES"
cd "$CUSTOM_NODES"

# List of repos to clone (Hearemen's Standard + Your Specifics)
repos=(
    # --- YOUR REQUESTS ---
    "https://github.com/princepainter/ComfyUI-PainterI2V.git"
    "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
    "https://github.com/Miosp/ComfyUI-FBCNN.git"
    
    # --- HEAREMEN'S STANDARD PACK ---
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
    "https://github.com/kijai/ComfyUI-KJNodes.git"
    "https://github.com/rgthree/rgthree-comfy.git"
    "https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    "https://github.com/yolain/ComfyUI-Easy-Use.git"
    "https://github.com/kijai/ComfyUI-Florence2.git"
    "https://github.com/cubiq/ComfyUI_essentials.git"
    "https://github.com/chrisgoringe/cg-image-picker.git"
    "https://github.com/chrisgoringe/cg-use-everywhere.git"
    "https://github.com/kijai/ComfyUI-segment-anything-2.git"
    "https://github.com/welltop-cn/ComfyUI-TeaCache.git"
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    "https://github.com/1038lab/ComfyUI-RMBG.git"
)

for repo in "${repos[@]}"; do
    dir_name=$(basename "$repo" .git)
    if [ ! -d "$dir_name" ]; then
        echo "   ⬇️ Cloning $dir_name..."
        git clone "$repo"
        # Install requirements immediately if they exist
        if [ -f "$dir_name/requirements.txt" ]; then
             # Filter out Torch to prevent downgrades
             grep -vE "torch|torchvision|torchaudio" "$dir_name/requirements.txt" > "$dir_name/reqs_clean.txt"
             pip install --no-cache-dir -r "$dir_name/reqs_clean.txt" &
        fi
    else
        echo "   ✅ $dir_name exists."
    fi
done
wait # Wait for pip installs to finish

# 6. DOWNLOAD: Robust Model Downloader Function
# Usage: download_file "URL" "OUTPUT_PATH" "AUTH_HEADER (Optional)"
download_file() {
    local url="$1"
    local out="$2"
    local auth="${3:-}"
    
    mkdir -p "$(dirname "$out")"
    if [ -f "$out" ]; then
        echo "   ✅ Exists: $(basename "$out")"
        return
    fi
    
    echo "   ⬇️ Downloading: $(basename "$out")"
    
    if [ -n "$auth" ]; then
        # Use aria2c with header for CivitAI
        aria2c -c -x 8 -s 8 -k 1M -q --header="$auth" -d "$(dirname "$out")" -o "$(basename "$out")" "$url"
    else
        # Standard download
        aria2c -c -x 8 -s 8 -k 1M -q -d "$(dirname "$out")" -o "$(basename "$out")" "$url"
    fi
}

echo "⬇️  Downloading Models..."

# --- YOUR REQUESTED MODELS ---

# Wan 2.2 Remix (High/Low)
download_file "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" \
              "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"

download_file "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" \
              "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"

# UMT5 NSFW
download_file "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" \
              "$CLIP_DIR/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"

# Upscaler
# Gdown fallback for Drive links
if [ ! -f "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth" ]; then
    gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth"
fi

# --- CIVITAI LORAS (With Token) ---
CIV_TOKEN="Authorization: Bearer 1fbae9052dd92d22f2d66081452c188b"

download_file "https://civitai.com/api/download/models/2312759" "$LORA_DIR/boobiefixer_high.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2312689" "$LORA_DIR/boobiefixer_low.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2284083" "$LORA_DIR/penis_fixer_high.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2284089" "$LORA_DIR/penis_fixer_low.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2073605" "$LORA_DIR/nsfwsks_high.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2083303" "$LORA_DIR/nsfwsks_low.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2190476" "$LORA_DIR/DR34ML4Y_nsfw_low.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2176505" "$LORA_DIR/DR34ML4Y_nsfw_high.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2496721" "$LORA_DIR/pussy_asshole_low.safetensors" "$CIV_TOKEN"
download_file "https://civitai.com/api/download/models/2496754" "$LORA_DIR/pussy_asshole_high.safetensors" "$CIV_TOKEN"

# GDrive LoRAs
[ ! -f "$LORA_DIR/Instagirlv2.5-LOW.safetensors" ] && gdown --id 1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF -O "$LORA_DIR/Instagirlv2.5-LOW.safetensors"
[ ! -f "$LORA_DIR/Instagirlv2.5-HIGH.safetensors" ] && gdown --id 1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0 -O "$LORA_DIR/Instagirlv2.5-HIGH.safetensors"


# 7. LAUNCH: Final checks and startup
echo "⏳ Waiting for SageAttention build..."
while ! [ -f /tmp/sage_build_done ]; do
    if ps -p $SAGE_PID > /dev/null 2>&1; then
        echo "   ...still building SageAttention"
        sleep 5
    else
        echo "⚠️ SageAttention build exited. Checking logs..."
        # Optional: cat /tmp/sage_build.log
        break
    fi
done
echo "✅ SageAttention Ready."

echo "🚀 Starting ComfyUI..."
cd "$COMFY_DIR"
# --use-sage-attention is CRITICAL for Wan 2.1 performance
exec python main.py --listen 0.0.0.0 --port 8188 --preview-method auto --use-sage-attention
