# Tool Substitution Rules

## Node.js: pnpm を使う（npm 禁止）

- npm は使用禁止。代わりに pnpm を使うこと。
- コマンド対応表:
  - `npm install` → `pnpm install`
  - `npm run <script>` → `pnpm <script>`
  - `npx <cmd>` → `pnpm exec <cmd>` or `pnpm dlx <cmd>`
  - `npm add <pkg>` → `pnpm add <pkg>`

## Python: uv を使う（pip 禁止）

- pip は使用禁止。代わりに uv を使うこと。
- コマンド対応表:
  - `pip install <pkg>` → `uv add <pkg>`
  - `pip install -r requirements.txt` → `uv sync`
  - `python script.py` → `uv run script.py`
  - `pip freeze` → `uv pip freeze`（uv pip は許可）

## ファイル削除: trash を使う（rm / rmdir 禁止）

- rm / rmdir は使用禁止。代わりに trash を使うこと。
- コマンド対応表:
  - `rm <file>` → `trash <file>`
  - `rm -r <dir>` → `trash <dir>`
  - `rmdir <dir>` → `trash <dir>`
