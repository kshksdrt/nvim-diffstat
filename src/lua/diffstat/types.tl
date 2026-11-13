-- Documented in doc/diffstat.txt; keep in step.

local record M
   record FileStat
      path: string
      old_path: string -- renames only
      added: integer -- 0 for binary files
      removed: integer
      binary: boolean
   end

   record Stat
      root: string
      args: {string} -- empty means HEAD
      files: {FileStat}
      added: integer
      removed: integer
      untracked: {string} -- only filled when args is empty
      updated_at: integer
   end

   record FloatConfig
      border: string
      max_width: integer
   end

   record Config
      interval_ms: integer -- 0 disables the background refresh
      args: {string}
      untracked: boolean
      format: function(Stat): string
      float: FloatConfig
      dir: function(): string -- nil follows the current buffer
   end
end

return M
