local types = require("diffstat.types")
local git = require("diffstat.git")
local view = require("diffstat.view")
local type Config = types.Config
local type Stat = types.Stat

local record M end

local TITLE = "Git Diff Stat"

local function default_format(s: Stat): string
   local parts: {string} = {}
   if #s.files > 0 then
      parts[#parts + 1] = "+" .. tostring(s.added) .. " -" .. tostring(s.removed)
   end
   if #s.untracked > 0 then
      parts[#parts + 1] = "?" .. tostring(#s.untracked)
   end
   return table.concat(parts, " ")
end

local defaults: Config = {
   interval_ms = 10000,
   args = {},
   untracked = true,
   format = default_format,
   float = { border = "rounded", max_width = 120 },
   dir = nil,
}

local config: Config = defaults
local last: Stat = nil
local timer: vim.Timer = nil
local started, applied, inflight = 0, 0, 0

local function start_dir(): string
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

function M.get(): Stat
   return last
end

function M.statusline(): string
   if not last then
      return ""
   end
   local ok, text = pcall(config.format, last)
   return ok and text or ""
end

function M.refresh(args?: {string}, cb?: function(Stat, string))
   started = started + 1
   inflight = inflight + 1
   local seq = started
   git.stat(start_dir(), args or config.args, config.untracked, function(stat: Stat, err: string)
      inflight = inflight - 1
      -- A result older than the stored one is dropped. Git errors keep the
      -- stored result; running outside a repository clears it.
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

-- Returns true when there is something to show.
local function report(stat: Stat, err: string): boolean
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

function M.show(args?: {string})
   M.refresh(args, function(stat: Stat, err: string)
      if report(stat, err) then
         view.open(stat, config.float)
      end
   end)
end

function M.refresh_verbose(args?: {string})
   M.refresh(args, function(stat: Stat, err: string)
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
         -- Skip a tick rather than pile up git processes.
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

function M.setup(opts?: Config)
   config = vim.tbl_deep_extend("force", defaults, opts or {})
   M.stop()
   M.start()
end

return M
