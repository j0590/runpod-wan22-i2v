#!/usr/bin/env bash
set -u

# --- HEAREMEN STANDARD HEADER ---
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PATH="/opt/venv/bin:$PATH"

# SageAttention Build
echo "⚙️  Starting SageAttention build..."
(
    cd /tmp
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    git reset --hard 68de379
    export NVCC_APPEND_FLAGS="--threads 4"
    pip install -e .
    echo "SageAttention build completed" > /tmp/sage_build_done
) > /tmp/sage_build.log 2>&1 &
SAGE_PID=$!

# Volume Setup
NETWORK_VOLUME="/workspace"
URL="http://127.0.0.1:8188"

if [ ! -d "$NETWORK_VOLUME" ]; then
    echo "⚠️  No Volume. Using root."
    NETWORK_VOLUME="/"
else
    echo "✅  Volume found."
fi

COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"
CUSTOM_NODES_DIR="$NETWORK_VOLUME/ComfyUI/custom_nodes"
WORKFLOW_DIR="$NETWORK_VOLUME/ComfyUI/user/default/workflows"

# Sync ComfyUI
if [ ! -d "$COMFYUI_DIR" ]; then
    cp -a /ComfyUI/. "$COMFYUI_DIR/"
fi

# CivitAI Helper
echo "Downloading CivitAI download script..."
if [ ! -f "/usr/local/bin/download_with_aria.py" ]; then
    git clone "https://github.com/Hearmeman24/CivitAI_Downloader.git"
    mv CivitAI_Downloader/download_with_aria.py "/usr/local/bin/"
    chmod +x "/usr/local/bin/download_with_aria.py"
    rm -rf CivitAI_Downloader
fi
pip install onnxruntime-gpu &

# --- INSTALL CUSTOM NODES (Hearemen + YOURS) ---
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"

# Helper to clone
clone_node() {
    if [ ! -d "$2" ]; then
        git clone "$1"
    else
        cd "$2" && git pull && cd ..
    fi
}

echo "🧩 Installing Nodes..."

# 1. YOUR NODES
clone_node "https://github.com/princepainter/ComfyUI-PainterI2V.git" "ComfyUI-PainterI2V"
clone_node "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git" "ComfyUI-WanMoeKSampler"
clone_node "https://github.com/Miosp/ComfyUI-FBCNN.git" "ComfyUI-FBCNN"

# 2. HEAREMEN NODES
clone_node "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "ComfyUI-WanVideoWrapper"
clone_node "https://github.com/kijai/ComfyUI-KJNodes.git" "ComfyUI-KJNodes"
clone_node "https://github.com/wildminder/ComfyUI-VibeVoice.git" "ComfyUI-VibeVoice"
clone_node "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git" "ComfyUI-WanAnimatePreprocess"
clone_node "https://github.com/obisin/ComfyUI-FSampler.git" "ComfyUI-FSampler"
clone_node "https://github.com/cmeka/ComfyUI-WanMoEScheduler.git" "ComfyUI-WanMoEScheduler"
clone_node "https://github.com/lrzjason/ComfyUI-VAE-Utils.git" "ComfyUI-VAE-Utils"

# Install Requirements (Background)
echo "🔧 Installing Node Requirements..."
pip install --no-cache-dir -r "$CUSTOM_NODES_DIR/ComfyUI-KJNodes/requirements.txt" &
pip install --no-cache-dir -r "$CUSTOM_NODES_DIR/ComfyUI-WanVideoWrapper/requirements.txt" &
pip install --no-cache-dir -r "$CUSTOM_NODES_DIR/ComfyUI-VibeVoice/requirements.txt" &
pip install --no-cache-dir -r "$CUSTOM_NODES_DIR/ComfyUI-WanAnimatePreprocess/requirements.txt" &

# Setup Models Dirs
DIFF_DIR="$NETWORK_VOLUME/ComfyUI/models/diffusion_models"
TEXT_DIR="$NETWORK_VOLUME/ComfyUI/models/text_encoders"
CLIP_DIR="$NETWORK_VOLUME/ComfyUI/models/clip_vision"
VAE_DIR="$NETWORK_VOLUME/ComfyUI/models/vae"
LORA_DIR="$NETWORK_VOLUME/ComfyUI/models/loras"
DET_DIR="$NETWORK_VOLUME/ComfyUI/models/detection"
UPSCALE_DIR="$NETWORK_VOLUME/ComfyUI/models/upscale_models"
mkdir -p "$DIFF_DIR" "$TEXT_DIR" "$CLIP_DIR" "$VAE_DIR" "$LORA_DIR" "$DET_DIR" "$UPSCALE_DIR"

# Download Helper
download_model() {
    local url="$1"
    local full_path="$2"
    local auth="${3:-}" # Support for auth headers
    
    if [ -f "$full_path" ]; then
        echo "✅ Exists: $(basename "$full_path")"
        return
    fi
    echo "📥 Downloading: $(basename "$full_path")"
    
    if [ -n "$auth" ]; then
        aria2c -x 16 -s 16 -k 1M -q --header="$auth" -d "$(dirname "$full_path")" -o "$(basename "$full_path")" "$url"
    else
        aria2c -x 16 -s 16 -k 1M -q -d "$(dirname "$full_path")" -o "$(basename "$full_path")" "$url"
    fi
}

echo "⬇️  Downloading Models..."

# --- 1. CRITICAL DEPENDENCIES (VAEs / Encoders) ---
# Without these, your Remix model will output gray noise
download_model "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "$TEXT_DIR/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
download_model "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors" "$TEXT_DIR/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors"
download_model "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "$CLIP_DIR/clip_vision_h.safetensors"
download_model "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" "$VAE_DIR/Wan2_1_VAE_bf16.safetensors"
download_model "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "$VAE_DIR/wan_2.1_vae.safetensors"

# --- 2. YOUR REQUESTED MODELS ---
# Wan 2.2 Remix (NSFW)
download_model "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
download_model "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
# NSFW UMT5
download_model "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$CLIP_DIR/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"

# Upscaler (GDrive fallback)
if [ ! -f "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth" ]; then
    gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth"
fi

# --- 3. YOUR LORAS (CivitAI) ---
CIV_TOKEN="Authorization: Bearer 1fbae9052dd92d22f2d66081452c188b"
download_model "https://civitai.com/api/download/models/2312759" "$LORA_DIR/boobiefixer_high.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2312689" "$LORA_DIR/boobiefixer_low.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2284083" "$LORA_DIR/penis_fixer_high.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2284089" "$LORA_DIR/penis_fixer_low.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2073605" "$LORA_DIR/nsfwsks_high.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2083303" "$LORA_DIR/nsfwsks_low.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2190476" "$LORA_DIR/DR34ML4Y_nsfw_low.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2176505" "$LORA_DIR/DR34ML4Y_nsfw_high.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2496721" "$LORA_DIR/pussy_asshole_low.safetensors" "$CIV_TOKEN"
download_model "https://civitai.com/api/download/models/2496754" "$LORA_DIR/pussy_asshole_high.safetensors" "$CIV_TOKEN"

# --- 4. YOUR LORAS (GDrive) ---
[ ! -f "$LORA_DIR/Instagirlv2.5-LOW.safetensors" ] && gdown --id 1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF -O "$LORA_DIR/Instagirlv2.5-LOW.safetensors"
[ ! -f "$LORA_DIR/Instagirlv2.5-HIGH.safetensors" ] && gdown --id 1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0 -O "$LORA_DIR/Instagirlv2.5-HIGH.safetensors"

# Rename Zips
cd "$LORA_DIR" && for file in *.zip; do mv "$file" "${file%.zip}.safetensors"; done

# Wait for SageAttention
echo "⏳ Waiting for SageAttention build..."
while ! [ -f /tmp/sage_build_done ]; do
    if ps -p $SAGE_PID > /dev/null 2>&1; then echo "Building..."; sleep 5; else break; fi
done
echo "✅ SageAttention Ready."

# Launch
echo "🚀 Starting ComfyUI..."
cd "$COMFYUI_DIR"
nohup python3 main.py --listen --use-sage-attention > "$NETWORK_VOLUME/comfyui_${RUNPOD_POD_ID}_nohup.log" 2>&1 &

# Hearemen Health Check Loop
counter=0
max_wait=45
until curl --silent --fail "$URL" --output /dev/null; do
    if [ $counter -ge $max_wait ]; then
        echo "⚠️  ComfyUI Startup Timeout. Check logs."
        break
    fi
    echo "🔄  ComfyUI Starting Up..."
    sleep 2
    counter=$((counter + 2))
done

if curl --silent --fail "$URL" --output /dev/null; then echo "🚀 ComfyUI is UP"; fi
sleep infinity
