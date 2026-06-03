#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/bin/aws-ecs-port-forward"

mkdir -p "${ROOT_DIR}/.cctmp/scratch"
tmp="$(mktemp -d "${ROOT_DIR}/.cctmp/scratch/aws-ecs-port-forward-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

stub_bin="${tmp}/stub-bin"
mkdir -p "$stub_bin"

fzf_log="${tmp}/fzf-input.log"
ssm_log="${tmp}/ssm.log"
describe_json="${tmp}/describe-tasks.json"
: > "$fzf_log"
: > "$ssm_log"

# describe-tasks の戻り値。tasks[0] は family:revision = datahub-backend:42
cat > "$describe_json" <<'JSON'
{
  "tasks": [
    {
      "taskArn": "arn:aws:ecs:ap-northeast-1:123456789012:task/mycluster/aaa111",
      "taskDefinitionArn": "arn:aws:ecs:ap-northeast-1:123456789012:task-definition/datahub-backend:42",
      "containers": [
        { "name": "backend", "runtimeId": "rid-backend-1" }
      ]
    },
    {
      "taskArn": "arn:aws:ecs:ap-northeast-1:123456789012:task/mycluster/bbb222",
      "taskDefinitionArn": "arn:aws:ecs:ap-northeast-1:123456789012:task-definition/datahub-worker:7",
      "containers": [
        { "name": "worker", "runtimeId": "rid-worker-1" }
      ]
    }
  ]
}
JSON

# fzf スタブ: 受け取った標準入力を記録し、先頭行を選択結果として返す
cat > "${stub_bin}/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input="$(cat)"
printf '%s\n' "$input" >> "$FZF_LOG"
printf '%s\n' "----" >> "$FZF_LOG"
first="${input%%$'\n'*}"
printf '%s\n' "$first"
EOF
chmod +x "${stub_bin}/fzf"

# aws スタブ: list-tasks / describe-tasks / ssm start-session をハンドリング
cat > "${stub_bin}/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
svc="${1:-}"; action="${2:-}"
if [[ "$svc" == "ecs" && "$action" == "list-tasks" ]]; then
  printf '%s\t%s\n' \
    "arn:aws:ecs:ap-northeast-1:123456789012:task/mycluster/aaa111" \
    "arn:aws:ecs:ap-northeast-1:123456789012:task/mycluster/bbb222"
  exit 0
fi
if [[ "$svc" == "ecs" && "$action" == "describe-tasks" ]]; then
  cat "$DESCRIBE_JSON"
  exit 0
fi
if [[ "$svc" == "ssm" && "$action" == "start-session" ]]; then
  echo "aws $*" >> "$AWS_SSM_LOG"
  exit 0
fi
echo "UNHANDLED aws $*" >&2
exit 0
EOF
chmod +x "${stub_bin}/aws"

# session-manager-plugin スタブ: 存在チェックを通すだけ
cat > "${stub_bin}/session-manager-plugin" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${stub_bin}/session-manager-plugin"

# Task / Mode は対話選択 (fzf スタブが先頭行を選ぶ) になるよう、それ以外を引数で確定させる
FZF_LOG="$fzf_log" AWS_SSM_LOG="$ssm_log" DESCRIBE_JSON="$describe_json" \
  PATH="${stub_bin}:$PATH" "$SCRIPT" \
  --cluster mycluster --container backend --local-port 15432 --remote-port 5432

# 1) Task 選択の fzf 入力に taskDefinition family:revision が含まれること
if ! grep -q 'datahub-backend:42' "$fzf_log"; then
  echo "ERROR: fzf に渡された Task 一覧に family:revision (datahub-backend:42) が含まれていません" >&2
  echo "--- fzf input ---" >&2
  cat "$fzf_log" >&2
  exit 1
fi

# 2) 選択行から taskArn を正しく取り出し、SSM target が組み立てられること
if ! grep -q 'ecs:mycluster_aaa111_rid-backend-1' "$ssm_log"; then
  echo "ERROR: 選択した task の ID/runtimeId から SSM target が正しく組み立てられていません" >&2
  echo "--- ssm call ---" >&2
  cat "$ssm_log" >&2
  exit 1
fi

echo "ok: aws-ecs-port-forward task selection shows family:revision"
