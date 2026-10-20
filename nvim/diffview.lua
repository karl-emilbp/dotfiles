return {
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
		opts = { enhanced_diff_hl = true },
		keys = {
			{ "<leader>gvv", "<cmd>DiffviewOpen<cr>", desc = "Diff working tree" },
			{ "<leader>gvp", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "Diff vs previous commit" },
			{ "<leader>gvf", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
			{ "<leader>gvh", "<cmd>DiffviewFileHistory<cr>", desc = "Repo history" },
			{ "<leader>gvq", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
		},
	},
	{
		"folke/which-key.nvim",
		opts = { spec = { { "<leader>gv", group = "diffview" } } },
	},
}
