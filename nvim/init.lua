-- disable netrw at the very start of init.lua for nvim-tree
-- https://github.com/nvim-tree/nvim-tree.lua?tab=readme-ov-file#setup
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- 行番号を表示
vim.opt.number = true

-- enable 24-bit colour
vim.opt.termguicolors = true
-- カラースキームを設定
-- vim.cmd('colorscheme desert')

-- インデント設定
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.modelines = 5

vim.opt.smartindent = true

-- タブ操作のキーマッピング
vim.api.nvim_set_keymap('n', 'tc', ':tabe<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'te', ':tabe ', { noremap = true })
vim.api.nvim_set_keymap('n', 'to', ':tabe ', { noremap = true })
vim.api.nvim_set_keymap('n', 'tn', ':tabnext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'tp', ':tabNext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', 'td', ':tabclose<CR>', { noremap = true, silent = true })

-- C-c を Esc にマッピング（InsertLeave autocmd が発火するようにする）
vim.api.nvim_set_keymap('i', '<C-c>', '<Esc>', { noremap = true, silent = true })

-- nvim-tree
vim.api.nvim_set_keymap('n', '<Space>n', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

require("config.lazy")

