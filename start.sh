#!/usr/bin/env bash
set -euo pipefail
export WORKDIR=/workspace/ComfyUI
export COMFYUI_ARGS="${COMFYUI_ARGS:---listen 0.0.0.0 --port 8188}"
mkdir -p /workspace
if [ ! -d "$WORKDIR" ]; then cp -a /ComfyUI "$WORKDIR"; fi
mkdir -p "$WORKDIR/models/diffusion_models" "$WORKDIR/models/clip" "$WORKDIR/models/vae" "$WORKDIR/models/loras" "$WORKDIR/models/upscale_models" "$WORKDIR/user/default/workflows"
if [ -f /moeksampler.json ]; then cp -f /moeksampler.json "$WORKDIR/user/default/workflows/moeksampler.json"; fi
dl(){ url="$1"; out="$2"; if [ -f "$out" ]; then echo "OK: $out"; else aria2c -x16 -s16 -k1M -o "$(basename "$out")" -d "$(dirname "$out")" "$url"; fi }
dltoken(){ url="$1"; out="$2"; hdr="$3"; if [ -f "$out" ]; then echo "OK: $out"; else curl -L -H "$hdr" "$url" -o "$out"; fi }
dl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$WORKDIR/models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
dl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$WORKDIR/models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
dl "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$WORKDIR/models/clip/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
if [ ! -f "$WORKDIR/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth" ]; then gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$WORKDIR/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth"; fi
if [ ! -f "$WORKDIR/models/loras/Instagirlv2.5-LOW.safetensors" ]; then gdown --id 1pwkyAiN15RxocVPsSEdebVUbhSaDUdIF -O "$WORKDIR/models/loras/Instagirlv2.5-LOW.safetensors"; fi
if [ ! -f "$WORKDIR/models/loras/Instagirlv2.5-HIGH.safetensors" ]; then gdown --id 1BfU6o4ICsN5o-NTB5PAoQEK5n1c1j4B0 -O "$WORKDIR/models/loras/Instagirlv2.5-HIGH.safetensors"; fi
if [ -n "${civitai_token:-}" ]; then dltoken "https://civitai.com/api/download/models/2312759" "$WORKDIR/models/loras/boobiefixer_high.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2312689" "$WORKDIR/models/loras/boobiefixer_low.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2284083" "$WORKDIR/models/loras/penis_fixer_high.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2284089" "$WORKDIR/models/loras/penis_fixer_low.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2073605" "$WORKDIR/models/loras/nsfwsks_high.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2083303" "$WORKDIR/models/loras/nsfwsks_low.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2012120" "$WORKDIR/models/loras/female_genitals_LOW.safetensors" "Authorization: Bearer ${civitai_token}"; fi
if [ ! -f "$WORKDIR/models/loras/i2v_lightx2v_high_noise_model.safetensors" ]; then echo "MISSING: i2v_lightx2v_high_noise_model.safetensors"; fi
if [ ! -f "$WORKDIR/models/loras/i2v_lightx2v_low_noise_model.safetensors" ]; then echo "MISSING: i2v_lightx2v_low_noise_model.safetensors"; fi
if [ ! -f "$WORKDIR/models/vae/wan_2.1_vae.safetensors" ]; then echo "MISSING: wan_2.1_vae.safetensors"; fi
cd "$WORKDIR"
python main.py $COMFYUI_ARGS
