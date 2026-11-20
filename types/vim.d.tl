-- Only the parts of the Neovim API this plugin uses.

global record vim
   record SystemCompleted
      code: integer
      signal: integer
      stdout: string
      stderr: string
   end

   record SystemOpts
      cwd: string
      env: {string:string}
      text: boolean
      stdin: string
   end

   record SystemObj
      pid: integer
      kill: function(self, signal: integer | string)
      wait: function(self, timeout?: integer): SystemCompleted
   end

   record SplitOpts
      plain: boolean
      trimempty: boolean
   end

   record Timer
      start: function(self, timeout: integer, rep: integer, cb: function()): integer
      stop: function(self): integer
      close: function(self)
      is_closing: function(self): boolean
   end

   record WinConfig
      relative: string
      width: integer
      height: integer
      row: integer
      col: integer
      style: string
      border: string
      title: string
      title_pos: string
   end

   record CommandArgs
      fargs: {string}
      bang: boolean
   end

   record CommandOpts
      nargs: string
      bang: boolean
      complete: function(lead: string, line: string, pos: integer): {string}
      desc: string
   end

   record ExecAutocmdOpts
      pattern: string
      data: any
      modeline: boolean
   end

   record OptionOpts
      buf: integer
      win: integer
   end

   record HlOpts
      link: string
      default: boolean
   end

   record ExtmarkOpts
      end_col: integer
      hl_group: string
   end

   record KeymapOpts
      buffer: integer
      nowait: boolean
      desc: string
   end

   record api
      nvim_buf_get_name: function(buf: integer): string
      nvim_buf_set_extmark: function(buf: integer, ns: integer, row: integer, col: integer, opts: ExtmarkOpts): integer
      nvim_buf_set_lines: function(buf: integer, start: integer, finish: integer, strict: boolean, lines: {string})
      nvim_command: function(cmd: string)
      nvim_create_buf: function(listed: boolean, scratch: boolean): integer
      nvim_create_namespace: function(name: string): integer
      nvim_create_user_command: function(name: string, fn: function(CommandArgs), opts: CommandOpts)
      nvim_exec_autocmds: function(event: string, opts: ExecAutocmdOpts)
      nvim_get_option_value: function(name: string, opts: OptionOpts): any
      nvim_open_win: function(buf: integer, enter: boolean, config: WinConfig): integer
      nvim_set_hl: function(ns: integer, name: string, val: HlOpts)
      nvim_set_option_value: function(name: string, value: any, opts: OptionOpts)
      nvim_win_close: function(win: integer, force: boolean)
      nvim_win_is_valid: function(win: integer): boolean
   end

   record fn
      getcwd: function(): string
      isdirectory: function(path: string): integer
      strcharpart: function(s: string, start: integer, len?: integer): string
      strchars: function(s: string): integer
      strdisplaywidth: function(s: string): integer
   end

   record fs
      dirname: function(path: string): string
   end

   record keymap
      set: function(mode: string, lhs: string, rhs: function(), opts?: KeymapOpts)
   end

   record log
      record levels
         DEBUG: integer
         INFO: integer
         WARN: integer
         ERROR: integer
      end
   end

   record o
      columns: integer
      lines: integer
   end

   record FsStat
      type: string
      size: integer
   end

   record uv
      new_timer: function(): Timer
      fs_lstat: function(path: string): FsStat
   end

   g: {string:any}

   notify: function(msg: string, level?: integer, opts?: {string:any})
   schedule: function(fn: function())
   startswith: function(s: string, prefix: string): boolean
   split: function(s: string, sep: string, opts?: SplitOpts): {string}
   system: function(cmd: {string}, opts?: SystemOpts, on_exit?: function(SystemCompleted)): SystemObj
   tbl_deep_extend: function<T>(behavior: string, a: T, b: T): T
   trim: function(s: string): string
end
