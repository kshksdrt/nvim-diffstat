# nvim-diffstat

Shows how many lines your git changes add and remove. It runs `git diff --numstat` in the background (every 10 s by default) and when you run `:GitDiffStat`. The latest result from either source is stored, so you can put it in your statusline or read it from Lua.

```
 init.lua                   |   3 ++-
 lua/commands/diff_stat.lua | 121 ++++++++++++++++++++++++++++
 2 files changed, 123 insertions(+), 1 deletion(-)

 Untracked (not counted above):
   notes.md
```

Requires Neovim 0.10+ and git.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'kshksdrt/nvim-diffstat',
  opts = {}, -- calls require('diffstat').setup(), which starts the background refresh
  keys = { { '<leader>hc', '<Cmd>GitDiffStat<CR>', desc = 'git diff stat' } },
}
```

`:GitDiffStat` works without `setup()`. Calling `setup()` starts the timer.

## Use

| | |
|---|---|
| `:GitDiffStat [args]` | Refresh and show a float. `args` replace `HEAD`: `--staged`, `main...HEAD`, … |
| `:GitDiffStat! [args]` | Refresh without the float |
| `require('diffstat').get()` | Last result: `{ root, args, files, added, removed, untracked, updated_at }` |
| `require('diffstat').statusline()` | Last result formatted, `+12 -3 ?2` by default |
| `User DiffStatUpdated` | Fires after each refresh that lands, with the result as `data` |

```lua
-- lualine
sections = { lualine_x = { function() return require('diffstat').statusline() end } }
```

## Options

```lua
require('diffstat').setup {
  interval_ms = 10000, -- background refresh period; 0 turns it off
  args = {},           -- default `git diff` args; empty = HEAD vs working tree
  untracked = true,    -- list untracked files when comparing against HEAD
  format = nil,        -- function(stat): string for statusline()
  float = { border = 'rounded', max_width = 120 },
}
```

The full reference is in [`:h diffstat`](doc/diffstat.txt).

## Development

The plugin is written in [Teal](https://github.com/teal-language/tl). The sources in `src/` compile to `lua/` and `plugin/`, and the compiled Lua is committed so installing the plugin needs no build step.

```sh
make          # compile src/**/*.tl (fetches the pinned compiler into .tools/ the first time)
make check    # type-check only
make test     # headless tests against throwaway repos
make verify   # fail if the committed Lua doesn't match a fresh build (CI runs this)
```

`types/vim.d.tl` declares only the parts of the Neovim API the plugin uses. When the code needs a new API, add it there. Warnings fail the build.
