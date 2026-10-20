-- Reload buffers when agents (Claude Code, Codex) or git change files on disk.
local reload = vim.api.nvim_create_augroup("agent_autoreload", { clear = true })

local function checktime()
	if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
		pcall(vim.cmd.checktime)
	end
end

vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = reload,
	callback = checktime,
})

local timer = vim.uv.new_timer()
if timer then
	timer:start(1000, 1000, vim.schedule_wrap(checktime))
end

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = reload,
	callback = function(args)
		vim.notify("Reloaded " .. vim.fn.fnamemodify(args.file, ":."), vim.log.levels.INFO)
	end,
})
