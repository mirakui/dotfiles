require("config.lazy")

-- 行番号を表示
vim.opt.number = true

-- カラースキームを設定
vim.cmd('colorscheme desert')

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

