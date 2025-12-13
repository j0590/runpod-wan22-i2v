#!/usr/bin/env bash
set -e

mkdir -p \
  /workspace/ComfyUI/models/diffusion_models \
  /workspace/ComfyUI/models/clip \
  /workspace/ComfyUI/models/loras \
  /workspace/ComfyUI/models/vae \
  /workspace/ComfyUI/models/upscale_models

rm -rf /ComfyUI/models
ln -s /workspace/ComfyUI/models /ComfyUI/models

download_wan22="${download_wan22:-true}"
civitai_token="${civitai_token:-}"

if [ "$download_wan22" = "true" ]; then
  aria2c -x16 -s16 -k1M -d /workspace/ComfyUI/models/diffusion_models \
    https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors \
    https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors
fi

aria2c -x16 -s16 -k1M -d /workspace/ComfyUI/models/clip \
  https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors

aria2c -x16 -s16 -k1M -d /workspace/ComfyUI/models/vae \
  https://huggingface.co/Wan-AI/Wan2.1/resolve/main/wan_2.1_vae.safetensors || true

if [ -n "$civitai_token" ]; then
  curl -L -H "Authorization: Bearer $civitai_token" https://civitai.com/api/download/models/2312759 -o /workspace/ComfyUI/models/loras/boobiefixer_high.safetensors
  curl -L -H "Authorization: Bearer $civitai_token" https://civitai.com/api/download/models/2312689 -o /workspace/ComfyUI/models/loras/boobiefixer_low.safetensors
  curl -L -H "Authorization: Bearer $civitai_token" https://civitai.com/api/download/models/2284083 -o /workspace/ComfyUI/models/loras/penis_fixer_high.safetensors
  curl -L -H "Authorization: Bearer $civitai_token" https://civitai.com/api/download/models/2284089 -o /workspace/ComfyUI/models/loras/penis_fixer_low.safetensors
fi

python /ComfyUI/main.py --listen 0.0.0.0 --port 8188
