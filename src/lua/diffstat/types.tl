-- Shared records. The public ones (Stat, FileStat, Config) are documented in
-- doc/diffstat.txt; keep the two in step.

local record M
   -- One row of `git diff --numstat`.
   record FileStat
      path: string
      old_path: string -- set for renames/copies only
      added: integer -- 0 for binary files
      removed: integer
      binary: boolean
   end

   -- The result of the last refresh, background or manual.
   record Stat
      root: string -- repository top level
      args: {string} -- revisions/flags given to `git diff`
      files: {FileStat}
      added: integer -- total lines added
      removed: integer -- total lines removed
      untracked: {string} -- empty unless the default comparison ran
      updated_at: integer -- os.time() when this result landed
   end

   record FloatConfig
      border: string
      max_width: integer
   end

   record Config
      interval_ms: integer -- background refresh period; 0 disables it
      args: {string} -- default `git diff` args; empty means HEAD
      untracked: boolean -- list untracked files for the default comparison
      format: function(Stat): string -- statusline text
      float: FloatConfig
   end
end

return M
