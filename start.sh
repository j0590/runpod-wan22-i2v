#!/usr/bin/env bash
set -euo pipefail

ts() { date +"%Y-%m-%dT%H:%M:%S"; }
log() { echo "$(ts) - $*"; }

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
VENV_DIR="${VENV_DIR:-/workspace/venvs/py312-5090}"
BOOT_DIR="${BOOT_DIR:-/workspace/.bootstrap/py312-5090}"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"

COMFY_HOST="${COMFY_HOST:-0.0.0.0}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFYUI_ARGS="${COMFYUI_ARGS:-"--listen ${COMFY_HOST} --port ${COMFY_PORT}"}"

CLONE_JOBS="${CLONE_JOBS:-8}"

# Persistent caches (big speedup after first run)
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.cache}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-/workspace/.cache/pip}"
export TORCHINDUCTOR_CACHE_DIR="${TORCHINDUCTOR_CACHE_DIR:-/workspace/.cache/torchinductor}"
export TRITON_CACHE_DIR="${TRITON_CACHE_DIR:-/workspace/.cache/triton}"
mkdir -p "$XDG_CACHE_HOME" "$PIP_CACHE_DIR" "$TORCHINDUCTOR_CACHE_DIR" "$TRITON_CACHE_DIR" "$BOOT_DIR"

# ---------- helpers ----------
aria_get() {
  local url="$1"
  local out="$2"
  if [ -f "$out" ]; then
    log "✅ Exists: $out"
    return 0
  fi
  log "⬇️  Downloading: $url"
  aria2c -c -x 8 -s 8 -k 1M --allow-overwrite=false -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
}

clone_repo() {
  local name="$1"
  local url="$2"
  local dest="$3"

  if [ -d "$dest" ]; then
    log "✅ Node exists: $name"
    return 0
  fi

  log "📥 Cloning: $name"
  mkdir -p "$(dirname "$dest")"

  # Prevent git from hanging asking for credentials
  export GIT_TERMINAL_PROMPT=0

  # If you set GITHUB_TOKEN in your pod env, this avoids GitHub rate-limit auth prompts.
  local clone_url="$url"
  if [ -n "${GITHUB_TOKEN:-}" ] && [[ "$url" == https://github.com/* ]]; then
    clone_url="${url/https:\/\/github.com\//https:\/\/x-access-token:${GITHUB_TOKEN}@github.com/}"
  fi

  if git clone --depth=1 --filter=blob:none "$clone_url" "$dest" 2>/dev/null; then
    return 0
  fi

  # Fallback: GitHub tarball (works even when git clone prompts / rate-limits oddly)
  if [[ "$url" == https://github.com/* ]]; then
    local owner_repo="${url#https://github.com/}"
    owner_repo="${owner_repo%.git}"
    for branch in main master; do
      local tar="https://codeload.github.com/${owner_repo}/tar.gz/refs/heads/${branch}"
      log "🔁 git failed; trying tarball: ${owner_repo}@${branch}"
      if curl -fsSL "$tar" | tar -xz -C "$(dirname "$dest")"; then
        local extracted
        extracted="$(dirname "$dest")/$(basename "$owner_repo")-${branch}"
        if [ -d "$extracted" ]; then
          mv "$extracted" "$dest"
          return 0
        fi
      fi
    done
  fi

  log "⚠️  FAILED to fetch node: $name ($url) — continuing so you don't get restart-loops."
  return 0
}

install_requirements_filtered() {
  local reqfile="$1"
  [ -f "$reqfile" ] || return 0

  local tmp
  tmp="$(mktemp)"
  # Filter packages that break your CUDA stack or your LayerStyle OpenCV ximgproc
  grep -vE '^(torch|torchvision|torchaudio)\b' "$reqfile" \
    | grep -vE '^(opencv-python|opencv-python-headless)\b' \
    > "$tmp" || true

  if [ -s "$tmp" ]; then
    log "📦 pip install (filtered): $reqfile"
    pip install -r "$tmp"
  fi
  rm -f "$tmp"
}

# ---------- 1) Ensure ComfyUI code on /workspace ----------
if [ ! -d "$COMFY_DIR" ]; then
  log "📁 Seeding ComfyUI into /workspace (first boot)"
  cp -a /ComfyUI "$COMFY_DIR"
else
  log "✅ ComfyUI present: $COMFY_DIR"
fi

mkdir -p "$CUSTOM_NODES"

# ---------- 2) Create /workspace venv ----------
if [ ! -d "$VENV_DIR" ]; then
  log "🐍 Creating venv: $VENV_DIR"
  python3.12 -m venv "$VENV_DIR"
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install -U pip setuptools wheel

# ---------- 3) Install Torch 2.8.0 + cu128 (ONE TIME) ----------
if [ ! -f "$BOOT_DIR/.torch_done" ]; then
  log "🔥 Installing Torch 2.8.0 (cu128 index) into /workspace venv"
  # This is the reliable way (no +cu128 spec); CUDA is selected by the cu128 index. :contentReference[oaicite:2]{index=2}
  pip install \
    torch==2.8.0 \
    torchvision==0.23.0 \
    torchaudio==2.8.0 \
    --index-url https://download.pytorch.org/whl/cu128

  python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
print("gpu:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "NO CUDA")
PY

  touch "$BOOT_DIR/.torch_done"
else
  log "✅ Torch already installed (marker found)"
fi

# ---------- 4) ComfyUI python deps (ONE TIME) ----------
if [ ! -f "$BOOT_DIR/.comfy_reqs_done" ]; then
  log "📦 Installing ComfyUI requirements"
  pip install -r "$COMFY_DIR/requirements.txt"
  # Frontend package sometimes lives separately in newer ComfyUI builds
  pip install -U comfyui-frontend-package
  touch "$BOOT_DIR/.comfy_reqs_done"
else
  log "✅ ComfyUI requirements already done"
fi

# ---------- 5) Restore ALL your custom nodes ----------
# Required / core nodes (put your "must have for workflow" here)
declare -a REPOS=(
  "ComfyUI-KJNodes|https://github.com/kijai/ComfyUI-KJNodes.git"
  "ComfyUI-WanVideoWrapper|https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
  "ComfyUI-WanMoeKSampler|https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
  "ComfyUI-PainterI2V|https://github.com/princepainter/ComfyUI-PainterI2V.git"
  "ComfyUI-FBCNN|https://github.com/Miosp/ComfyUI-FBCNN.git"
)

# Your OPTIONAL_REPOS block (kept exactly in spirit, plus a couple from your logs)
declare -a OPTIONAL_REPOS=(
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

  # Seen in your logs (nice-to-have)
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
  "ComfyUI_Comfyroll_CustomNodes|https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
  "ComfyUI_JPS-Nodes|https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git"
  "ComfyUI-Frame-Interpolation|https://github.com/Kosinkadink/ComfyUI-Frame-Interpolation.git"
)

log "🧩 Cloning required nodes"
pids=()
for entry in "${REPOS[@]}"; do
  IFS='|' read -r name url <<<"$entry"
  (
    clone_repo "$name" "$url" "$CUSTOM_NODES/$name"
  ) &
  pids+=($!)
  if [ "${#pids[@]}" -ge "$CLONE_JOBS" ]; then
    wait -n || true
  fi
done
for pid in "${pids[@]}"; do wait "$pid" || true; done

log "🧩 Cloning optional nodes"
pids=()
for entry in "${OPTIONAL_REPOS[@]}"; do
  IFS='|' read -r name url <<<"$entry"
  (
    clone_repo "$name" "$url" "$CUSTOM_NODES/$name"
  ) &
  pids+=($!)
  if [ "${#pids[@]}" -ge "$CLONE_JOBS" ]; then
    wait -n || true
  fi
done
for pid in "${pids[@]}"; do wait "$pid" || true; done

log "✅ Custom nodes complete"

# ---------- 6) Install node requirements (ONE TIME, filtered) ----------
if [ ! -f "$BOOT_DIR/.node_reqs_done" ]; then
  log "📦 Installing node requirements (filtered)"
  while IFS= read -r reqfile; do
    install_requirements_filtered "$reqfile"
  done < <(find "$CUSTOM_NODES" -maxdepth 3 -name requirements.txt 2>/dev/null || true)

  # Fix LayerStyle guidedFilter: needs cv2.ximgproc (opencv-contrib)
  log "🛠️  Enforcing opencv-contrib-python (fixes cv2.ximgproc guidedFilter)"
  pip uninstall -y opencv-python opencv-python-headless >/dev/null 2>&1 || true
  pip install -U opencv-contrib-python

  # Fix WanVideoWrapper warning (optional feature): onnx not installed
  pip install -U onnx onnxruntime >/dev/null 2>&1 || true

  touch "$BOOT_DIR/.node_reqs_done"
  log "✅ Node requirements done"
else
  log "✅ Node requirements already done"
fi

# ---------- 7) Fix ComfyLiterals web extension warning ----------
if [ -d "$CUSTOM_NODES/ComfyLiterals/web" ]; then
  mkdir -p "$COMFY_DIR/web/extensions"
  if [ ! -e "$COMFY_DIR/web/extensions/ComfyLiterals" ]; then
    ln -s "$CUSTOM_NODES/ComfyLiterals/web" "$COMFY_DIR/web/extensions/ComfyLiterals" || true
    log "✅ Linked ComfyLiterals web extension"
  fi
fi

# ---------- 8) Install SageAttention (fixes your crash) ----------
if [ ! -f "$BOOT_DIR/.sageattention_done" ]; then
  log "⚡ Installing sageattention (required by KJNodes PatchSageAttentionKJ)"

  # First try pip package (fast). If you want SA2 kernels on 5090/CUDA12.8+, build from source. :contentReference[oaicite:3]{index=3}
  pip install -U sageattention || true

  if ! python -c "import sageattention" >/dev/null 2>&1; then
    log "🔧 pip package not available; building SageAttention from source (one-time)"
    pip install -U ninja
    SAGE_DIR="/workspace/src/SageAttention"
    if [ ! -d "$SAGE_DIR" ]; then
      git clone --depth=1 https://github.com/thu-ml/SageAttention.git "$SAGE_DIR"
    fi
    (cd "$SAGE_DIR" && pip install -v -e .) || true
  fi

  python - <<'PY' || true
try:
  import sageattention
  print("sageattention OK")
except Exception as e:
  print("sageattention install FAILED:", e)
PY

  touch "$BOOT_DIR/.sageattention_done"
else
  log "✅ sageattention already handled"
fi

# ---------- 9) Fix your workflow Lightning LoRA validation failure ----------
LORA_DIR="$COMFY_DIR/models/loras"
mkdir -p "$LORA_DIR"

# These are exactly what your workflow asked for by name.
# Files exist in Lightx2v’s Wan2.2-Lightning repo. :contentReference[oaicite:4]{index=4}
BASE="https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1"
aria_get "$BASE/high_noise_model.safetensors" "$LORA_DIR/i2v_lightx2v_high_noise_model.safetensors"
aria_get "$BASE/low_noise_model.safetensors"  "$LORA_DIR/i2v_lightx2v_low_noise_model.safetensors"
log "✅ Lightning LoRAs present"

# ---------- 10) Launch ----------
log "🚀 Starting ComfyUI: ${COMFYUI_ARGS}"
cd "$COMFY_DIR"
exec python main.py ${COMFYUI_ARGS}
