-- Run with `make test`.

vim.opt.rtp:prepend '.'
vim.cmd.runtime 'plugin/diffstat.lua'

local diffstat = require 'diffstat'
local git = require 'diffstat.git'
local view = require 'diffstat.view'

local failures, total = 0, 0
local function test(name, fn)
  total = total + 1
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    failures = failures + 1
    io.stderr:write('FAIL ' .. name .. '\n' .. tostring(err) .. '\n')
  else
    print('ok   ' .. name)
  end
end
local function eq(want, got, what)
  if not vim.deep_equal(want, got) then
    error(('%s: want %s, got %s'):format(what or 'value', vim.inspect(want), vim.inspect(got)), 2)
  end
end

local tmp = vim.fn.tempname()
local function sh(dir, cmd)
  local r = vim.system({ 'sh', '-c', cmd }, { cwd = dir, text = true }):wait()
  assert(r.code == 0, cmd .. ': ' .. (r.stderr or ''))
end
local function repo(name)
  local dir = tmp .. '/' .. name
  vim.fn.mkdir(dir, 'p')
  sh(dir, 'git init -q && git config user.email t@t && git config user.name t && git config commit.gpgsign false')
  return dir
end

--- Refresh from `dir` and wait for this call's own callback.
local function refresh_in(dir, args)
  vim.cmd.cd(dir)
  local done, stat, err = false, nil, nil
  diffstat.refresh(args, function(s, e)
    done, stat, err = true, s, e
  end)
  assert(vim.wait(5000, function()
    return done
  end), 'refresh timed out')
  return stat, err
end

test('parse_numstat: plain, binary, rename', function()
  local out = '3\t1\ta.lua\0-\t-\timg.png\0' .. '0\t2\t\0old name.txt\0new\tname.txt\0'
  eq({
    { path = 'a.lua', added = 3, removed = 1, binary = false },
    { path = 'img.png', added = 0, removed = 0, binary = true },
    { path = 'new\tname.txt', old_path = 'old name.txt', added = 0, removed = 2, binary = false },
  }, git.parse_numstat(out))
  eq({}, git.parse_numstat '', 'empty output')
end)

test('render: rows, bar scaling, summary', function()
  local stat = {
    args = {},
    added = 101,
    removed = 50,
    untracked = { 'new.txt' },
    files = {
      { path = 'big.lua', added = 100, removed = 50, binary = false },
      { path = 'small.lua', added = 1, removed = 0, binary = false },
      { path = 'img.png', added = 0, removed = 0, binary = true },
    },
  }
  local lines, spans = view.render(stat, 40)
  -- " " name(9) " | " count(3) " " => 17 fixed cells, so 23 for the bar.
  eq(' big.lua   | 150 ' .. ('+'):rep(15) .. ('-'):rep(8), lines[1], 'scaled row')
  eq(' small.lua |   1 +', lines[2], 'smallest change keeps one mark')
  eq(' img.png   | Bin', lines[3], 'binary row')
  eq(' 3 files changed, 101 insertions(+), 50 deletions(-)', lines[4], 'summary')
  eq({ '', ' Untracked (not counted above):', '   new.txt' }, { lines[5], lines[6], lines[7] }, 'untracked')
  eq({ row = 0, col = 17, end_col = 32, group = 'DiffStatAdded' }, spans[1], 'added span')
  eq({ row = 0, col = 32, end_col = 40, group = 'DiffStatRemoved' }, spans[2], 'removed span')
  for _, l in ipairs(lines) do
    assert(vim.fn.strdisplaywidth(l) <= 52, 'row too wide: ' .. l)
  end
end)

test('render: long names are shortened from the left', function()
  local stat = {
    args = {}, added = 1, removed = 0, untracked = {},
    files = { { path = ('d/'):rep(40) .. 'file.lua', added = 1, removed = 0, binary = false } },
  }
  local lines = view.render(stat, 40)
  assert(lines[1]:match '^ %.%.%..*file%.lua | ', lines[1])
  assert(vim.fn.strdisplaywidth(lines[1]) <= 40, lines[1])
end)

local r = repo 'main'
sh(r, 'printf "a\\nb\\nc\\n" > f.txt && git add f.txt && git commit -qm init')

test('refresh: clean repo has no changes and an empty statusline', function()
  local stat, err = refresh_in(r)
  eq(nil, err)
  eq(vim.fs.normalize(vim.uv.fs_realpath(r)), stat.root, 'root')
  eq(0, #stat.files)
  eq('', diffstat.statusline())
end)

test('refresh: staged + unstaged + untracked, and the update event', function()
  sh(r, 'printf "a\\nB\\nc\\nd\\n" > f.txt && printf "x\\n" > staged.txt && git add staged.txt && echo u > untracked.txt')
  local seen
  vim.api.nvim_create_autocmd('User', {
    pattern = 'DiffStatUpdated',
    once = true,
    callback = function(ev)
      seen = ev.data
    end,
  })
  local stat = refresh_in(r)
  eq(3, stat.added, 'added')
  eq(1, stat.removed, 'removed')
  eq({ 'untracked.txt' }, stat.untracked)
  eq(stat, diffstat.get(), 'get() returns the last result')
  eq('+3 -1 ?1', diffstat.statusline())
  eq(stat.added, seen and seen.added, 'event data')
end)

test('refresh: explicit args replace HEAD and skip untracked', function()
  local stat = refresh_in(r, { '--staged' })
  eq({ '--staged' }, stat.args)
  eq({ { path = 'staged.txt', added = 1, removed = 0, binary = false } }, stat.files)
  eq({}, stat.untracked)
  eq('+1 -0', diffstat.statusline(), 'manual call persists')
end)

test('refresh: bad args keep the previous result', function()
  local before = diffstat.get()
  local stat, err = refresh_in(r, { 'no-such-rev' })
  eq(nil, stat)
  assert(err and err:match 'no%-such%-rev', 'error message: ' .. tostring(err))
  eq(before, diffstat.get())
end)

test('refresh: repository without commits', function()
  local u = repo 'unborn'
  sh(u, 'printf "1\\n2\\n" > a && git add a && echo z > b')
  local stat, err = refresh_in(u)
  eq(nil, err)
  eq(2, stat.added)
  eq({ 'b' }, stat.untracked)
end)

test('refresh: outside a repository clears the result', function()
  local plain = tmp .. '/plain'
  vim.fn.mkdir(plain, 'p')
  local stat, err = refresh_in(plain)
  eq(nil, stat)
  eq(nil, err)
  eq(nil, diffstat.get())
  eq('', diffstat.statusline())
end)

test('dir: follows the buffer by default, or runs where dir() says', function()
  local plain = tmp .. '/plain'
  vim.fn.mkdir(plain, 'p')
  vim.cmd.edit(plain .. '/notes.txt')
  eq(nil, (refresh_in(r)), 'buffer outside a repo, cwd inside one')
  diffstat.setup { interval_ms = 0, dir = vim.fn.getcwd }
  eq(vim.fn.resolve(r), vim.fn.resolve((refresh_in(r)).root), 'dir = getcwd')
  diffstat.setup { interval_ms = 0 }
  vim.cmd 'bwipeout!'
end)

test('background refresh picks up new changes', function()
  vim.cmd.cd(r)
  diffstat.setup { interval_ms = 100, format = function(s)
    return 'n=' .. #s.files
  end }
  assert(vim.wait(3000, function()
    return diffstat.statusline() == 'n=2'
  end), 'first tick: ' .. diffstat.statusline())
  sh(r, 'echo more >> other.txt && git add other.txt')
  assert(vim.wait(3000, function()
    return diffstat.statusline() == 'n=3'
  end), 'later tick: ' .. diffstat.statusline())
  diffstat.stop()
end)

test('setup with interval_ms = 0 runs no timer', function()
  diffstat.setup { interval_ms = 0 }
  local before = diffstat.get()
  vim.wait(300)
  eq(before, diffstat.get())
end)

test(':GitDiffStat opens a float; q closes it', function()
  vim.cmd.cd(r)
  local wins = #vim.api.nvim_list_wins()
  vim.cmd 'GitDiffStat'
  assert(vim.wait(5000, function()
    return #vim.api.nvim_list_wins() > wins
  end), 'no float opened')
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(lines[#lines - 1] == ' Untracked (not counted above):', vim.inspect(lines))
  eq('diffstat', vim.bo.filetype)
  vim.api.nvim_feedkeys('q', 'x', false)
  eq(wins, #vim.api.nvim_list_wins(), 'float closed')
end)

vim.fn.delete(tmp, 'rf')
print(('%d/%d passed'):format(total - failures, total))
os.exit(failures == 0 and 0 or 1)
