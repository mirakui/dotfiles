return {
  {
    "zbirenbaum/copilot.lua",
    config = function()
      require("copilot").setup({})
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    config = function()
      require("nvim-tree").setup({})
    end,
  },
}
