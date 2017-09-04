-- Copyright © 2016 Ganchrow Scientific, SA all rights reserved
--

-- luacheck: ignore 111
-- luacheck: globals redis cjson doTest focussedTest getFile flushKeys isFunction yaml client

redis = require('redis')
cjson = require('cjson')
yaml = require('yaml')

local get_config_option = require('lua-src.ext.get_config_option')
local Expector = require('lua-test.expector')

-- ensure helper modules or mocks are required over actual modules
local dir = arg[0]:match('(.*/)') or ''

-- strips out last segment of path
local kind = dir:reverse():sub(2, dir:reverse():sub(2):find('/')):reverse()
print(dir, kind)
package.path = dir .. '?.lua;' .. dir .. '../?.lua;' .. dir .. '../../?.lua;'.. package.path

function isFunction(thing)
  return type(thing) == 'function'
end

function getFile(scriptName)
  return dir .. '/../../target/test_scripts/' .. kind .. '/' .. scriptName .. '.lua'
end

function generateTests(tableOfTests)
  local tests = {}
  for what, t in pairs(tableOfTests) do
    tests[what] = t
  end
  return tests
end

function runTests(tests)
  for what, _ in pairs(tests) do
    local test = tests[what]
    for _, t in ipairs(test) do
      doTest(what, t, dir)
    end
  end

  assert(Expector.noFailures, 'TEST HAS FAILURES')
end

function flushKeys()
  for _, val in pairs(redis.call('keys', '*')) do
    if (not val:find('GS_SCRIPT')) then
      redis.call('del', val)
    end
  end
end

focussedTest = arg[1]

function doTest(name, with)
  if focussedTest and not (focussedTest == name) then
    return
  end
  local expector = Expector:new(name, with.tag)
  expector:init()

  local moduleFn = assert(loadfile(getFile(name)))
  local moduleToTest = moduleFn()
  flushKeys()
  if isFunction(with.setUp) then
    with.setUp(moduleToTest)
  end
  local testResult
  if isFunction(with.doTest) then
    testResult = with.doTest(moduleToTest)
  end
  local shouldBeTrue = with.expect(testResult, expector, moduleToTest)
  if isFunction(with.tearDown) then
    with.tearDown(moduleToTest)
  end
  expector:done(shouldBeTrue)
end

--

local config = yaml.loadpath('configs/redis.yaml')
local env = os.getenv('EXECUTION_ENVIRONMENT')
if (env ~= 'TESTING') then
  env = 'DEVELOPMENT'
end
local host, port, auth_pass, db, flush = unpack(
  get_config_option.get(config, env, 'data', 'host', 'port', 'auth_pass', 'db', 'flush')
)

if not (host and port) then
  os.exit(1)
end

print(host)
print(port)
print(auth_pass)
print(os.getenv('EXECUTION_ENVIRONMENT'))

client = redis.connect(host, port)
if auth_pass then
  client:auth(auth_pass)
end
if db then
  print('Using DB ' .. db)
  client:select(db)
else
  print('Using DB 9')
  client:select(9)
end
if flush then
  client:flushdb()
end

--[[
  Override default Lua behaviour. HGETALL is modified to produce the
  same result as the version built into Redis which returns a flat
  array of {key 1, val 1, key 2, val2, ...} whereas Redis in Lua returns a
  set {key 1 = val 1, key 2 = val 2, ...}
]]
redis.call = function(cmd, ...)
  -- uncomment for better debugging during tests
  -- print(cmd .. ':' .. cjson.encode({...}))
  if string.lower(cmd) == 'publish' then
    local args = {...}
    local channel = 'publish:' .. args[1]
    local val = args[2]
    return assert(loadstring('return client:lpush' .. '(...)'))(channel, val)
  elseif string.lower(cmd) == 'hgetall' then
    local hGetAll = assert(loadstring('return client:' .. string.lower(cmd) .. '(...)'))(...)
    if hGetAll then
      local hGetArray = {}
      for key, val in pairs(hGetAll) do
        table.insert(hGetArray, key)
        table.insert(hGetArray, val)
      end
      return hGetArray
    else
      return nil
    end
  else
    local result = assert(loadstring('return client:' .. string.lower(cmd) .. '(...)'))(...)
    -- uncomment for better debugging during tests
    -- print('result: ' .. cjson.encode(result))
    return result
  end
end
redis.log = function(msg)
  print(msg)
end
