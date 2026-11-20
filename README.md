# nvim-diffstat

`git diff --stat` for Neovim, untracked files included: in a float on demand, and refreshed in the background for your statusline.

Requires Neovim 0.10+.

## Install

```lua
-- lazy.nvim
{ 'kshksdrt/nvim-diffstat', opts = {} }
```

## Usage

- `:GitDiffStat [args]` shows the stat in a float. `args` replace `HEAD`, e.g. `--staged`, `main...HEAD`.
- `:GitDiffStat!` refreshes without the float.
- `require('diffstat').statusline()` returns `+12 -3 ?2` for the last refresh (`?2`: untracked files, whose lines are in `+12`).
- `require('diffstat').get()` returns the full result.
- `User DiffStatUpdated` fires after each refresh.

## Options

```lua
{
  interval_ms = 10000, -- 0 disables the background refresh
  args = {},           -- default git diff args; empty means HEAD
  untracked = true,
  format = nil,        -- function(stat): string
  float = { border = 'rounded', max_width = 120 },
  dir = nil,           -- function(): string; nil follows the buffer, vim.fn.getcwd the cwd
}
```

See `:h diffstat`.

## Development

Written in [Teal](https://github.com/teal-language/tl). `src/` compiles to `lua/` and `plugin/`, which are committed.

```sh
make          # build
make test
make verify   # fail if the committed Lua is stale
```
