-- Swarm Neovim Configuration
-- Simple, clean setup for step-by-step building

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.wrap = false
vim.opt.cursorline = true

-- Split settings for our layout
vim.opt.splitright = true
vim.opt.splitbelow = true

-- File explorer settings (netrw)
vim.g.netrw_banner = 0        -- Remove banner
vim.g.netrw_liststyle = 3     -- Tree style
vim.g.netrw_browse_split = 4  -- Open files in previous window
vim.g.netrw_altv = 1         -- Open splits to the right
vim.g.netrw_winsize = 25     -- 25% width for explorer

-- Auto-open file explorer on startup in vertical split
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Open netrw in vertical split on the left
    vim.cmd("Vexplore")
    -- Move to the right window (main editor)
    vim.cmd("wincmd l")
  end,
})

-- Key mappings
local map = vim.keymap.set

-- Toggle file explorer
map('n', '<C-e>', ':Vexplore<CR>', { desc = 'Toggle file explorer' })

-- Window navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Move to bottom window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Move to top window' })

-- Basic file operations
map('n', '<leader>w', ':w<CR>', { desc = 'Save file' })
map('n', '<leader>q', ':q<CR>', { desc = 'Quit' })

-- Set leader key
vim.g.mapleader = ' '

-- Simple status line
vim.opt.laststatus = 2
vim.opt.statusline = '%f %m %r%=Line: %l/%L Col: %c'