#!/usr/bin/env bash
set -u

# 1. OPTIMIZATION
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"
export PATH="/opt/venv/bin:$PATH"

# 2. SAGE ATTENTION (Background)
echo "⚙️  Starting SageAttention build..."
(
    cd /tmp
    git clone https://github.com/thu-ml/SageAttention.git
    cd SageAttention
    git reset --hard 68de379
    export NVCC_APPEND_FLAGS="--threads 4"
    pip install -e .
    echo "done" > /tmp/sage_build_done
) > /tmp/sage_build.log 2>&1 &
SAGE_PID=$!

# 3. VOLUME SETUP
if [ -d "/workspace" ]; then
    echo "✅ Network Volume detected."
    ROOT_DIR="/workspace"
else
    echo "⚠️ No Network Volume. Using ephemeral storage."
    ROOT_DIR="/"
fi

COMFY_DIR="$ROOT_DIR/ComfyUI"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
# Define all paths
DIFF_DIR="$COMFY_DIR/models/diffusion_models"
TEXT_DIR="$COMFY_DIR/models/text_encoders"
CLIP_DIR="$COMFY_DIR/models/clip_vision"
VAE_DIR="$COMFY_DIR/models/vae"
LORA_DIR="$COMFY_DIR/models/loras"
DET_DIR="$COMFY_DIR/models/detection"
UPSCALE_DIR="$COMFY_DIR/models/upscale_models"

# Sync ComfyUI
if [ ! -d "$COMFY_DIR" ] || [ -z "$(ls -A "$COMFY_DIR")" ]; then
    echo "📦 Copying ComfyUI to volume..."
    cp -a /ComfyUI/. "$COMFY_DIR/"
fi

# 4. INSTALL NODES
mkdir -p "$CUSTOM_NODES"
cd "$CUSTOM_NODES"

install_node() {
    local url="$1"
    local dir=$(basename "$url" .git)
    if [ ! -d "$dir" ]; then
        echo "   ⬇️ Cloning $dir..."
        git clone "$url"
        if [ -f "$dir/requirements.txt" ]; then
            # FILTER: Remove insightface/torch to prevent runtime rebuild crashes
            grep -vE "torch|torchvision|torchaudio|insightface|onnxruntime" "$dir/requirements.txt" > "$dir/reqs_clean.txt"
            pip install -r "$dir/reqs_clean.txt" &
        fi
    fi
}

echo "🧩 Installing Custom Nodes..."

# --- YOUR REQUESTS ---
install_node "https://github.com/princepainter/ComfyUI-PainterI2V.git"
install_node "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
install_node "https://github.com/Miosp/ComfyUI-FBCNN.git"

# --- HEAREMEN FULL PACK ---
install_node "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
install_node "https://github.com/kijai/ComfyUI-KJNodes.git"
install_node "https://github.com/wildminder/ComfyUI-VibeVoice.git"
install_node "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git"
install_node "https://github.com/obisin/ComfyUI-FSampler.git"
install_node "https://github.com/cmeka/ComfyUI-WanMoEScheduler.git"
install_node "https://github.com/lrzjason/ComfyUI-VAE-Utils.git"
install_node "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
install_node "https://github.com/rgthree/rgthree-comfy.git"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
install_node "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
install_node "https://github.com/Fannovel16/comfyui_controlnet_aux.git"
install_node "https://github.com/yolain/ComfyUI-Easy-Use.git"
install_node "https://github.com/kijai/ComfyUI-Florence2.git"
install_node "https://github.com/cubiq/ComfyUI_essentials.git"
install_node "https://github.com/chrisgoringe/cg-image-picker.git"
install_node "https://github.com/chrisgoringe/cg-use-everywhere.git"
install_node "https://github.com/kijai/ComfyUI-segment-anything-2.git"
install_node "https://github.com/welltop-cn/ComfyUI-TeaCache.git"
install_node "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
install_node "https://github.com/1038lab/ComfyUI-RMBG.git"

wait # Wait for reqs

# 5. DOWNLOAD MODELS (VAEs & Models)
mkdir -p "$DIFF_DIR" "$TEXT_DIR" "$CLIP_DIR" "$VAE_DIR" "$LORA_DIR" "$DET_DIR" "$UPSCALE_DIR"

download() {
    local url="$1"
    local out="$2"
    local auth="${3:-}"
    mkdir -p "$(dirname "$out")"
    if [ -f "$out" ]; then echo "   ✅ Exists: $(basename "$out")"; return; fi
    echo "   ⬇️ Downloading: $(basename "$out")"
    if [ -n "$auth" ]; then
        aria2c -c -x 8 -s 8 -k 1M -q --header="$auth" -d "$(dirname "$out")" -o "$(basename "$out")" "$url"
    else
        aria2c -c -x 8 -s 8 -k 1M -q -d "$(dirname "$out")" -o "$(basename "$out")" "$url"
    fi
}

echo "⬇️  Downloading Models..."

# --- CRITICAL DEPENDENCIES ---
download "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "$TEXT_DIR/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors" "$TEXT_DIR/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors"
download "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "$CLIP_DIR/clip_vision_h.safetensors"
download "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" "$VAE_DIR/Wan2_1_VAE_bf16.safetensors"
download "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" "$VAE_DIR/wan_2.1_vae.safetensors"

# --- DETECTION MODELS ---
download "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" "$DET_DIR/yolov10m.onnx"
download "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" "$DET_DIR/vitpose_h_wholebody_data.bin"
download "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" "$DET_DIR/vitpose_h_wholebody_model.onnx"

# --- YOUR MODELS ---
download "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
download "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$DIFF_DIR/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
download "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$CLIP_DIR/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"

# Upscaler
if [ ! -f "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth" ]; then
    gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$UPSCALE_DIR/1xSkinContrast-SuperUltraCompact.pth"
fi

# CivitAI
CIV_TOKEN="Authorization: Bearer 1fbae9052dd92d22f2d66081452c188b"
download "https://civitai.com/api/download/models/2312759" "$LORA_DIR/boobiefixer_high.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2312689" "$LORA_DIR/boobiefixer_low.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2284083" "$LORA_DIR/penis_fixer_high.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2284089" "$LORA_DIR/penis_fixer_low.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2073605" "$LORA_DIR/nsfwsks_high.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2083303" "$LORA_DIR/nsfwsks_low.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2190476" "$LORA_DIR/DR34ML4Y_nsfw_low.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2176505" "$LORA_DIR/DR34ML4Y_nsfw_high.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2496721" "$LORA_DIR/pussy_asshole_low.safetensors" "$CIV_TOKEN"
download "https://civitai.com/api/download/models/2496754" "$LORA_DIR/pussy_asshole_high.safetensors" "$CIV_TOKEN"

# GDrive
[ ! -f "$LORA_DIR/Instagirlv2.5-LOW.safetensors" ] && gdown --id 1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF -O "$LORA_DIR/Instagirlv2.5-LOW.safetensors"
[ ! -f "$LORA_DIR/Instagirlv2.5-HIGH.safetensors" ] && gdown --id 1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0 -O "$LORA_DIR/Instagirlv2.5-HIGH.safetensors"

# Rename Zips
cd "$LORA_DIR" && for file in *.zip; do mv "$file" "${file%.zip}.safetensors"; done

# 6. LAUNCH
echo "⏳ Waiting for SageAttention build..."
while ! [ -f /tmp/sage_build_done ]; do
    if ps -p $SAGE_PID > /dev/null 2>&1; then sleep 5; else break; fi
done
echo "✅ SageAttention Ready."

echo "🚀 Starting ComfyUI..."
cd "$COMFY_DIR"
exec python main.py --listen 0.0.0.0 --port 8188 --preview-method auto --use-sage-attention
