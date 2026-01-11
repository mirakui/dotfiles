#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/bin/git-ai-commit"

mkdir -p "${ROOT_DIR}/.cctmp/scratch"
tmp="$(mktemp -d "${ROOT_DIR}/.cctmp/scratch/git-ai-commit-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

stub_bin="${tmp}/stub-bin"
mkdir -p "$stub_bin"

log_file="${tmp}/calls.log"
touch "$log_file"

state_file="${tmp}/state.txt"

cat > "${stub_bin}/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "git \$*" >> "${log_file}"

if [[ "\${1:-}" == "add" && "\${2:-}" == "-u" ]]; then
  echo "added_u=1" > "${state_file}"
  exit 0
fi

if [[ "\${1:-}" == "diff" && "\${2:-}" == "--cached" && "\${3:-}" == "--quiet" ]]; then
  # Return non-zero to indicate there are staged changes
  exit 1
fi

if [[ "\${1:-}" == "diff" && "\${2:-}" == "--cached" ]]; then
  echo "diff --git a/tracked.txt b/tracked.txt"
  echo "+v2"
  exit 0
fi

if [[ "\${1:-}" == "commit" ]]; then
  exit 0
fi

exit 0
EOF
chmod +x "${stub_bin}/git"

cat > "${stub_bin}/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
echo "test: generated commit message"
EOF
chmod +x "${stub_bin}/claude"

cat > "${stub_bin}/cursor-agent" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
echo "test: generated commit message"
EOF
chmod +x "${stub_bin}/cursor-agent"

PATH="${stub_bin}:$PATH" "${SCRIPT}" -a
grep -q '^git add -u$' "$log_file"
grep -q '^git commit -m test: generated commit message' "$log_file"

# Ensure -am (bundled short options) behaves like -a and doesn't break on missing -m argument
rm -f "$log_file"
touch "$log_file"
PATH="${stub_bin}:$PATH" "${SCRIPT}" -am "ignored user message"
grep -q '^git add -u$' "$log_file"
if grep -q -- ' -am' "$log_file"; then
  echo "ERROR: -am should be consumed by git-ai-commit and not forwarded to git commit" >&2
  exit 1
fi
if grep -q -- 'ignored user message' "$log_file"; then
  echo "ERROR: user message argument for -m should be ignored/consumed by git-ai-commit" >&2
  exit 1
fi
grep -q '^git commit -m test: generated commit message' "$log_file"
