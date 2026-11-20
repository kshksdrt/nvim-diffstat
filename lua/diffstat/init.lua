-- Generated from src/lua/diffstat/init.tl by `make`. Do not edit.
local types = require("diffstat.types")
local git = require("diffstat.git")
local view = require("diffstat.view")



local M = {}

local TITLE = "Git Diff Stat"

local function default_format(s)
   local parts = {}
   if #s.files > 0 then
      parts[#parts + 1] = "+" .. tostring(s.added) .. " -" .. tostring(s.removed)
   end
   if #s.untracked > 0 then
      parts[#parts + 1] = "?" .. tostring(#s.untracked)
   end
   return table.concat(parts, " ")
end

local defaults = {
   interval_ms = 10000,
   args = {},
   untracked = true,
   format = default_format,
   float = { border = "rounded", max_width = 120 },
   dir = nil,
}

local config = defaults
local last = nil
local timer = nil
local started, applied, inflight = 0, 0, 0

local function start_dir()
   if config.dir then
      return config.dir()
   end
   local name = vim.api.nvim_buf_get_name(0)
   if vim.api.nvim_get_option_value("buftype", { buf = 0 }) == "" and name ~= "" then
      local dir = vim.fs.dirname(name)
      if vim.fn.isdirectory(dir) == 1 then
         return dir
      end
   end
   return vim.fn.getcwd()
end

function M.get()
   return last
end

function M.statusline()
   if not last then
      return ""
   end
   local ok, text = pcall(config.format, last)
   return ok and text or ""
end

function M.refresh(args, cb)
   started = started + 1
   inflight = inflight + 1
   local seq = started
   git.stat(start_dir(), args or config.args, config.untracked, function(stat, err)
      inflight = inflight - 1


      if seq > applied and not err then
         applied = seq
         local before = M.statusline()
         last = stat
         vim.api.nvim_exec_autocmds("User", { pattern = "DiffStatUpdated", data = stat, modeline = false })
         if M.statusline() ~= before then
            vim.api.nvim_command("redrawstatus!")
         end
      end
      if cb then
         cb(stat, err)
      end
   end)
end


local function report(stat, err)
   if err then
      vim.notify(err, vim.log.levels.ERROR, { title = TITLE })
   elseif not stat then
      vim.notify("Not inside a git repository.", vim.log.levels.WARN, { title = TITLE })
   elseif #stat.files == 0 and #stat.untracked == 0 then
      vim.notify("No changes.", vim.log.levels.INFO, { title = TITLE })
   else
      return true
   end
   return false
end

function M.show(args)
   M.refresh(args, function(stat, err)
      if report(stat, err) then
         view.open(stat, config.float)
      end
   end)
end



function M.compare(base, target)
   target = (target and target ~= "") and target or "HEAD"
   git.stat(start_dir(), { base .. "..." .. target }, false, function(stat, err)
      if report(stat, err) then

         stat.branch = nil
         view.open(stat, config.float)
      end
   end)
end


function M.refs()
   local r = vim.system({
      "git", "-C", start_dir(), "for-each-ref",
      "--format=%(refname:short)\t%(symref)",
      "refs/heads", "refs/remotes", "refs/tags",
   }, { text = true }):wait()
   local refs = {}
   if r.code ~= 0 then
      return refs
   end
   for _, line in ipairs(vim.split(r.stdout or "", "\n", { trimempty = true })) do
      local name, symref = line:match("^([^\t]*)\t(.*)$")

      if name and symref == "" then
         refs[#refs + 1] = name
      end
   end
   return refs
end

function M.refresh_verbose(args)
   M.refresh(args, function(stat, err)
      report(stat, err)
   end)
end

function M.start()
   if timer or config.interval_ms <= 0 then
      return
   end
   timer = vim.uv.new_timer()
   timer:start(0, config.interval_ms, function()
      vim.schedule(function()

         if inflight == 0 then
            M.refresh()
         end
      end)
   end)
end

function M.stop()
   if timer then
      timer:stop()
      timer:close()
      timer = nil
   end
end

function M.setup(opts)
   config = vim.tbl_deep_extend("force", defaults, opts or {})
   M.stop()
   M.start()
end

return M