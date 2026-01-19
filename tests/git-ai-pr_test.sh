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

body_file="${tmp}/gh_body.txt"
title_file="${tmp}/gh_title.txt"
prompt_file="${tmp}/ai_prompt.txt"
stderr_file="${tmp}/stderr.txt"
touch "$body_file" "$title_file" "$prompt_file" "$stderr_file"

fake_repo="${tmp}/repo"
mkdir -p "$fake_repo"

reset_case_files() {
  : >"$log_file"
  : >"$body_file"
  : >"$title_file"
  : >"$prompt_file"
  : >"$stderr_file"
}

run_git_ai_pr() {
  reset_case_files
  set +e
  PATH="${stub_bin}:$PATH" bash -c '
    if [[ ! -f "'"$SCRIPT"'" ]]; then
      echo "Expected file not found: '"$SCRIPT"'" >&2
      exit 1
    fi
    bash "'"$SCRIPT"'" "$@" 2>"'"$stderr_file"'"
  ' bash "$@"
  rc=$?
  set -e
  return "$rc"
}

cat > "${stub_bin}/git" <<EOF
#!/usr/bin/env bash
set -e
echo "git \$*" >> "${log_file}"

if [[ "\$1" == "rev-parse" && "\$2" == "--show-toplevel" ]]; then
  echo "${fake_repo}"
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
  # Capture --title / --body for assertions (body may contain newlines)
  args=( "\$@" )
  i=0
  while [[ \$i -lt \${#args[@]} ]]; do
    a="\${args[\$i]}"
    if [[ "\$a" == "--title" ]]; then
      i=\$((i + 1))
      printf '%s' "\${args[\$i]:-}" > "${title_file}"
    elif [[ "\$a" == "--body" ]]; then
      i=\$((i + 1))
      printf '%s' "\${args[\$i]:-}" > "${body_file}"
    fi
    i=\$((i + 1))
  done
  exit 0
fi

exit 0
EOF
chmod +x "${stub_bin}/gh"

cat > "${stub_bin}/claude" <<EOF
#!/usr/bin/env bash
set -e
echo "claude \$*" >> "${log_file}"

# Capture the last arg (the prompt) for assertions (may contain newlines)
printf '%s' "\${@: -1}" > "${prompt_file}"

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

# Case 1: no template -> body is AI body as-is; also opens browser by default
run_git_ai_pr --base main --draft
grep -q "gh pr create" "$log_file"
grep -q -- "--base main" "$log_file"
grep -q -- "--draft" "$log_file"
grep -q -- "gh pr view --web" "$log_file"
grep -q -- "feat: add git-ai-pr" "$title_file"
grep -q -- "This PR adds git-ai-pr." "$body_file"
# Ensure the PR description instruction explicitly says Japanese
grep -q -- "body (PR description) MUST be written in Japanese" "$prompt_file"

# Case 2: single template -> inject AI body after first matching heading
mkdir -p "${fake_repo}/.github"
cat > "${fake_repo}/.github/pull_request_template.md" <<'TPL'
## Summary

- Checklist item
TPL

run_git_ai_pr --base main --draft --no-open
grep -q -- "## Summary" "$body_file"
grep -q -- "This PR adds git-ai-pr." "$body_file"
awk '
  /This PR adds git-ai-pr\./ { ai=NR }
  /- Checklist item/ { chk=NR }
  END { if (!(ai>0 && chk>0 && ai < chk)) exit 1 }
' "$body_file"

# Case 3: multiple templates -> require --template
rm -f "${fake_repo}/.github/pull_request_template.md"
mkdir -p "${fake_repo}/.github/PULL_REQUEST_TEMPLATE"
cat > "${fake_repo}/.github/PULL_REQUEST_TEMPLATE/a.md" <<'TPL'
## Summary
from a
TPL
cat > "${fake_repo}/.github/PULL_REQUEST_TEMPLATE/b.md" <<'TPL'
## Summary
from b
TPL

if run_git_ai_pr --base main --draft --no-open; then
  echo "Expected failure due to multiple templates, but command succeeded" >&2
  exit 1
fi
grep -q -- "--template" "$stderr_file"

# Case 4: multiple templates + --template a -> choose a.md
run_git_ai_pr --base main --draft --no-open --template a
grep -q -- "from a" "$body_file"
