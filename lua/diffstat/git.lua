-- Generated from src/lua/diffstat/git.tl by `make`. Do not edit.
local types = require("diffstat.types")



local M = {}


local EMPTY_TREE = {
   sha1 = "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
   sha256 = "6ef19b41225c5369f1c104d45d8d85efa9b057b53b14b4b9b939dd74decc5321",
}


local GIT_ENV = { GIT_OPTIONAL_LOCKS = "0" }

local function git(dir, args, on_exit)
   local cmd = { "git", "-C", dir }
   for _, a in ipairs(args) do
      cmd[#cmd + 1] = a
   end

   local ok, err = pcall(vim.system, cmd, { text = true, env = GIT_ENV }, on_exit)
   if not ok then
      on_exit({ code = -1, signal = 0, stdout = "", stderr = tostring(err) })
   end
end



function M.parse_numstat(out)
   local files = {}
   local tokens = vim.split(out, "\0", { plain = true })
   local i = 1
   while i <= #tokens do
      local a, r, path = tokens[i]:match("^([%d-]+)\t([%d-]+)\t(.*)$")
      if a then
         local f = { path = path, added = 0, removed = 0, binary = a == "-" }
         if path == "" then
            f.old_path, f.path = tokens[i + 1], tokens[i + 2]
            i = i + 2
         end
         if not f.binary then
            f.added = math.floor(tonumber(a))
            f.removed = math.floor(tonumber(r))
         end
         files[#files + 1] = f
      end
      i = i + 1
   end
   return files
end



function M.stat(dir, args, with_untracked, cb)
   local function finish(stat, err)
      vim.schedule(function() cb(stat, err) end)
   end


   git(dir, { "rev-parse", "--show-toplevel", "--show-object-format", "--verify", "-q", "HEAD" }, function(res)
      local info = vim.split(res.stdout or "", "\n", { trimempty = true })
      if #info < 2 then
         return finish(nil, nil)
      end
      local root, format, head = info[1], info[2], info[3]
      local default = #args == 0

      local diff = { "diff", "--numstat", "-z" }
      if default then
         diff[#diff + 1] = head or EMPTY_TREE[format] or EMPTY_TREE.sha1
      else
         for _, a in ipairs(args) do
            diff[#diff + 1] = a
         end
      end

      local stat = {
         root = root,
         args = args,
         files = {},
         added = 0,
         removed = 0,
         untracked = {},
      }
      local list_untracked = default and with_untracked
      local pending = list_untracked and 2 or 1
      local err

      local function done()
         pending = pending - 1
         if pending > 0 then
            return
         end
         if err then
            return finish(nil, err)
         end
         for _, f in ipairs(stat.files) do
            stat.added = stat.added + f.added
            stat.removed = stat.removed + f.removed
         end
         stat.updated_at = os.time()
         finish(stat, nil)
      end

      git(root, diff, function(r)
         if r.code ~= 0 then
            err = vim.trim(r.stderr or "")
            if err == "" then
               err = "git diff exited with code " .. tostring(r.code)
            end
         else
            stat.files = M.parse_numstat(r.stdout or "")
         end
         done()
      end)

      if list_untracked then
         git(root, { "ls-files", "--others", "--exclude-standard", "-z" }, function(r)
            if r.code == 0 then
               stat.untracked = vim.split(r.stdout or "", "\0", { plain = true, trimempty = true })
            end
            done()
         end)
      end
   end)
end

return M