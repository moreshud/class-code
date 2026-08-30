#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  source "$ROOT/.env"
  set +a
fi
if [[ -x "$ROOT/.venv/bin/vllm" ]]; then
  export PATH="$ROOT/.venv/bin:$PATH"
fi
if [[ -n "${HF_TOKEN:-}" ]]; then
  export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
fi

MODEL=${MODEL:-Qwen/Qwen3-0.6B}

if ! command -v nvidia-smi &>/dev/null; then
  echo "launch_replicas.sh runs on the Lambda GPU, not the Mac." >&2
  echo "On your Mac:  cd class-code/class7 && bash setup/sync_to_lambda.sh && bash setup/ssh.sh" >&2
  exit 1
fi

if ! command -v vllm >/dev/null 2>&1; then
  echo "vllm not on PATH. On Lambda:  bash setup/lambda_setup.sh && source .venv/bin/activate"
  exit 1
fi

echo "starting two replicas of $MODEL  (max-num-seqs=8, gpu-memory-utilization=0.35)"

vllm serve "$MODEL" --port 8001 \
  --gpu-memory-utilization 0.35 \
  --max-num-seqs 8 \
  --max-model-len 16384 \
  --scheduling-policy priority \
  --served-model-name lab &
PID1=$!

vllm serve "$MODEL" --port 8002 \
  --gpu-memory-utilization 0.35 \
  --max-num-seqs 8 \
  --max-model-len 16384 \
  --scheduling-policy priority \
  --served-model-name lab &
PID2=$!

echo "$PID1" > /tmp/llm-gateway-lab-8001.pid
echo "$PID2" > /tmp/llm-gateway-lab-8002.pid
echo "pids $PID1 $PID2  — waiting for /v1/models (model download can take several minutes)"

ok=0
for i in $(seq 1 180); do
  if curl -sf http://127.0.0.1:8001/v1/models >/dev/null 2>&1 \
     && curl -sf http://127.0.0.1:8002/v1/models >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 2
done

if [[ "$ok" -ne 1 ]]; then
  echo "replicas did not become ready in 6 minutes"
  exit 1
fi

echo "replicas ready on :8001 and :8002"
echo "next:  bash setup/smoke_test.sh"
