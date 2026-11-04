-- Generated from src/lua/diffstat/view.tl by `make`. Do not edit.



local types = require("diffstat.types")



local M = { Span = {} }









local ns = vim.api.nvim_create_namespace("diffstat")

local MIN_BAR = 10

local function width(s)
   return vim.fn.strdisplaywidth(s)
end


local function fit(name, w)
   if width(name) <= w then
      return name
   end
   local tail = vim.fn.strcharpart(name, vim.fn.strchars(name) - (w - 3))
   while width(tail) > w - 3 do
      tail = vim.fn.strcharpart(tail, 1)
   end
   return "..." .. tail
end



local function scale(n, max, w)
   if n == 0 or max <= w then
      return n
   end
   return 1 + math.floor(n * (w - 1) / max)
end

local function plural(n, one, many)
   return tostring(n) .. " " .. (n == 1 and one or many)
end


function M.render(stat, max_width)
   local lines = {}
   local spans = {}

   local names = {}
   local name_w, count_w, max_change = 0, 3, 0
   for i, f in ipairs(stat.files) do
      names[i] = f.old_path and (f.old_path .. " => " .. f.path) or f.path
      name_w = math.max(name_w, width(names[i]))
      count_w = math.max(count_w, #tostring(f.added + f.removed))
      max_change = math.max(max_change, f.added + f.removed)
   end

   local fixed = 1 + 3 + count_w + 1
   name_w = math.max(4, math.min(name_w, max_width - fixed - MIN_BAR))
   local bar_w = math.max(1, max_width - fixed - name_w)

   for i, f in ipairs(stat.files) do
      local name = fit(names[i], name_w)
      local prefix = " " .. name .. string.rep(" ", name_w - width(name)) .. " | "
      if f.binary then
         lines[#lines + 1] = prefix .. "Bin"
      else
         local total = f.added + f.removed
         local marks = scale(total, max_change, bar_w)
         local plus = total > 0 and math.floor(marks * f.added / total + 0.5) or 0

         if f.added > 0 and plus == 0 then
            plus = 1
         elseif f.removed > 0 and plus == marks then
            plus = marks - 1
         end
         local count = tostring(total)
         prefix = prefix .. string.rep(" ", count_w - #count) .. count .. " "
         local row = #lines
         local c = #prefix
         spans[#spans + 1] = { row = row, col = c, end_col = c + plus, group = "DiffStatAdded" }
         spans[#spans + 1] = { row = row, col = c + plus, end_col = c + marks, group = "DiffStatRemoved" }
         lines[#lines + 1] = prefix .. string.rep("+", plus) .. string.rep("-", marks - plus)
      end
   end

   if #stat.files > 0 then
      local summary = " " .. plural(#stat.files, "file changed", "files changed")
      if stat.added > 0 then
         summary = summary .. ", " .. plural(stat.added, "insertion(+)", "insertions(+)")
      end
      if stat.removed > 0 then
         summary = summary .. ", " .. plural(stat.removed, "deletion(-)", "deletions(-)")
      end
      lines[#lines + 1] = summary
   end

   if #stat.untracked > 0 then
      if #lines > 0 then
         lines[#lines + 1] = ""
      end
      lines[#lines + 1] = " Untracked (not counted above):"
      for _, path in ipairs(stat.untracked) do
         lines[#lines + 1] = "   " .. path
      end
   end

   return lines, spans
end


function M.open(stat, cfg)
   local max_width = math.min(cfg.max_width, vim.o.columns - 4)
   local lines, spans = M.render(stat, max_width)

   local w = 0
   for _, line in ipairs(lines) do
      w = math.max(w, width(line) + 1)
   end
   w = math.min(w, max_width)
   local h = math.min(#lines, vim.o.lines - 4)


   vim.api.nvim_set_hl(0, "DiffStatAdded", { link = "Added", default = true })
   vim.api.nvim_set_hl(0, "DiffStatRemoved", { link = "Removed", default = true })

   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   for _, s in ipairs(spans) do
      if s.end_col > s.col then
         vim.api.nvim_buf_set_extmark(buf, ns, s.row, s.col, { end_col = s.end_col, hl_group = s.group })
      end
   end
   vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
   vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
   vim.api.nvim_set_option_value("filetype", "diffstat", { buf = buf })

   local label = #stat.args > 0 and table.concat(stat.args, " ") or "HEAD"
   local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = w,
      height = h,
      row = math.floor((vim.o.lines - h) / 2),
      col = math.floor((vim.o.columns - w) / 2),
      style = "minimal",
      border = cfg.border,
      title = " Git Diff Stat · " .. label .. " ",
   })
   for _, key in ipairs({ "q", "<Esc>" }) do
      vim.keymap.set("n", key, function()
         if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
         end
      end, { buffer = buf, nowait = true })
   end
end

return M