-- Defines :GitDiffStat. Loading the module waits for the first use, and the
-- background refresh only starts with require("diffstat").setup().

if vim.g.loaded_diffstat then
   return
end
vim.g.loaded_diffstat = true

vim.api.nvim_create_user_command("GitDiffStat", function(o: vim.CommandArgs)
   local diffstat = require("diffstat")
   local args = #o.fargs > 0 and o.fargs or nil
   if o.bang then
      diffstat.refresh_verbose(args)
   else
      diffstat.show(args)
   end
end, {
   nargs = "*",
   bang = true,
   desc = "Show line additions/deletions of current changes (git diff --stat); ! refreshes without the float",
})
