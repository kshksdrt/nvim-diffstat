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
   desc = "Show git diff --stat in a float; ! only refreshes",
})

vim.api.nvim_create_user_command("GitDiffStatCompare", function(o: vim.CommandArgs)
   if #o.fargs > 2 then
      vim.notify("GitDiffStatCompare takes {base} [target]", vim.log.levels.ERROR)
      return
   end
   require("diffstat").compare(o.fargs[1], o.fargs[2])
end, {
   nargs = "+",
   complete = function(lead: string, line: string): {string}
      -- Words so far, the command included; `lead` is the one being typed.
      local words = #vim.split(vim.trim(line), "%s+")
      if (lead == "" and words or words - 1) > 2 then
         return {}
      end
      local matches: {string} = {}
      for _, r in ipairs(require("diffstat").refs()) do
         if vim.startswith(r, lead) then
            matches[#matches + 1] = r
         end
      end
      return matches
   end,
   desc = "Show git diff --stat of {base}...[target] (default HEAD) in a float",
})
