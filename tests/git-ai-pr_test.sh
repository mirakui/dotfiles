#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/bin/git-ai-pr"

mkdir -p "${ROOT_DIR}/.cctmp/scratch"
tmp="$(mktemp -d "${ROOT_DIR}/.cctmp/scratch/git-ai-pr-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

stub_bin="${tmp}/stub-bin"
mkdir -p "$stub_bin"

log_file="${tmp}/calls.log"
touch "$log_file"

cat > "${stub_bin}/git" <<EOF
#!/usr/bin/env bash
set -e
echo "git \$*" >> "${log_file}"

if [[ "\$1" == "rev-parse" && "\$2" == "--show-toplevel" ]]; then
  echo "/fake/repo"
  exit 0
fi

if [[ "\$1" == "rev-parse" && "\$2" == "--abbrev-ref" && "\$3" == "HEAD" ]]; then
  echo "feature/test"
  exit 0
fi

if [[ "\$1" == "rev-parse" && "\$2" == "--verify" && "\${3:-}" == "origin/main" ]]; then
  echo "deadbeef"
  exit 0
fi

if [[ "\$1" == "diff" ]]; then
  # expected: git diff --no-color origin/main...HEAD
  echo "diff --git a/foo b/foo"
  echo "+hello"
  exit 0
fi

if [[ "\$1" == "log" ]]; then
  echo "abc1234 feat: add thing"
  exit 0
fi

if [[ "\$1" == "symbolic-ref" && "\$2" == "refs/remotes/origin/HEAD" ]]; then
  echo "refs/remotes/origin/main"
  exit 0
fi

exit 0
EOF
chmod +x "${stub_bin}/git"

cat > "${stub_bin}/gh" <<EOF
#!/usr/bin/env bash
set -e
echo "gh \$*" >> "${log_file}"

if [[ "\$1 \$2" == "repo view" ]]; then
  # For: gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
  echo "main"
  exit 0
fi

if [[ "\$1 \$2" == "pr create" ]]; then
  exit 0
fi

exit 0
EOF
chmod +x "${stub_bin}/gh"

cat > "${stub_bin}/claude" <<EOF
#!/usr/bin/env bash
set -e
echo "claude \$*" >> "${log_file}"

# Simulate \`claude --output-format json\` returning structured_output
cat <<JSON
{"structured_output":{"title":"feat: add git-ai-pr","body":"This PR adds git-ai-pr."}}
JSON
EOF
chmod +x "${stub_bin}/claude"

cat > "${stub_bin}/cursor-agent" <<EOF
#!/usr/bin/env bash
set -e
echo "cursor-agent \$*" >> "${log_file}"
cat <<JSON
{"title":"feat: add git-ai-pr","body":"This PR adds git-ai-pr."}
JSON
EOF
chmod +x "${stub_bin}/cursor-agent"

PATH="${stub_bin}:$PATH" bash -c '
  if [[ ! -f "'"$SCRIPT"'" ]]; then
    echo "Expected file not found: '"$SCRIPT"'" >&2
    exit 1
  fi
  bash "'"$SCRIPT"'" --base main --draft
'

# Assertions: gh pr create called with title/body/base/draft
grep -q "gh pr create" "$log_file"
grep -q -- "--base main" "$log_file"
grep -q -- "--draft" "$log_file"
grep -q -- "--title feat: add git-ai-pr" "$log_file"
grep -q -- "--body This PR adds git-ai-pr." "$log_file"

# Assertions: open browser after creating PR
grep -q "gh pr view --web" "$log_file"
