-- Compiles src/X.tl to X.lua. Run via `make`. --check only type-checks.
-- Warnings fail the build.

local check_only = arg[1] == '--check'

package.path = './.tools/?.lua;' .. package.path
local tl = require 'tl'

tl.path = './src/lua/?.tl;./src/lua/?/init.tl;./types/?.d.tl'

local function list_sources()
  local files = {}
  local p = assert(io.popen "find src -name '*.tl' ! -name '*.d.tl' | sort")
  for line in p:lines() do
    files[#files + 1] = line
  end
  p:close()
  return files
end

local function report(kind, errs)
  for _, e in ipairs(errs or {}) do
    io.stderr:write(('%s:%d:%d: %s: %s\n'):format(e.filename, e.y, e.x, kind, e.msg or ''))
  end
  return errs and #errs or 0
end

local failed = 0
for _, src in ipairs(list_sources()) do
  local env = assert(tl.new_env {
    defaults = { feat_lax = 'off', gen_target = '5.1', gen_compat = 'off' },
    predefined_modules = { 'vim' },
  })
  local result, err = tl.check_file(src, env)
  if not result then
    io.stderr:write(err .. '\n')
    failed = failed + 1
  else
    local n = 0
    for _, name in ipairs(env.loaded_order) do
      local r = env.loaded[name]
      n = n + report('syntax error', r.syntax_errors)
      n = n + report('error', r.type_errors)
      n = n + report('warning', r.warnings)
    end
    if n > 0 then
      failed = failed + 1
    elseif not check_only then
      local code, gen_err = tl.generate(result.ast, '5.1')
      if not code then
        io.stderr:write(src .. ': ' .. tostring(gen_err) .. '\n')
        failed = failed + 1
      else
        local out = src:gsub('^src/', ''):gsub('%.tl$', '.lua')
        os.execute("mkdir -p '" .. out:match '^(.*)/' .. "'")
        local f = assert(io.open(out, 'w'))
        f:write('-- Generated from ' .. src .. ' by `make`. Do not edit.\n', code)
        f:close()
        print(src .. ' -> ' .. out)
      end
    end
  end
end

-- Remove generated files whose source is gone.
if not check_only and failed == 0 then
  local sources = {}
  for _, src in ipairs(list_sources()) do
    sources[src] = true
  end
  local p = assert(io.popen "find lua plugin -name '*.lua' 2>/dev/null")
  for out in p:lines() do
    local f = assert(io.open(out))
    local src = (f:read '*l' or ''):match '^%-%- Generated from (%S+) by'
    f:close()
    if src and not sources[src] then
      os.remove(out)
      print('removed ' .. out .. ' (' .. src .. ' is gone)')
    end
  end
  p:close()
end

if failed > 0 then
  io.stderr:write(failed .. ' file(s) failed\n')
  os.exit(1)
end
