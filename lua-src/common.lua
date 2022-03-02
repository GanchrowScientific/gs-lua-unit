-- Copyright © 2017-2022 Ganchrow Scientific, SA all rights reserved
--

-- luacheck: ignore 111
-- luacheck: globals redis cjson yaml bit

-- Require globally
cjson = require('cjson')
yaml = require('lyaml')
redis = require('redis')
bit = require('bit')

yaml.loadpath = function(file)
  local f = io.open(file, 'r')
  local contents = f:read('*all')
  f:close()
  return yaml.load(contents)
end

-- ensure helper modules or mocks are required over actual modules
local dir = arg[0]:match('(.*/)') or ''

-- strips out last segment of path
local kind = dir:reverse():sub(2, dir:reverse():sub(2):find('/')):reverse()
local baseDir = '/../../target/test_scripts/'
local projectPath = arg[1]
local focussedTest = arg[2]

if projectPath then
  projectPath = projectPath .. '/'
else
  projectPath = dir .. '../../'
end

print(dir, kind)

package.path = dir .. '?.lua;' .. dir .. '../?.lua;' .. dir .. '../../?.lua;' ..
  projectPath .. 'node_modules/gs-lua-unit/lua-src/?.lua;' .. package.path

local Expector = require('/expector')
local mockRedisClient = require('/mockRedisClient')

local function flushKeys()
  for _, val in pairs(redis.call('keys', '*')) do
    if (not val:find('GS_SCRIPT')) then
      redis.call('del', val)
    end
  end
end

local function isFunction(thing)
  return type(thing) == 'function'
end

local function getFile(scriptName)
  return dir .. baseDir .. kind .. '/' .. scriptName .. '.lua'
end
-- loads the target module and optionally includes a set of upvalues (ie- local globals)
local function safeLoadModule(name, upvalues)
  local chunk = assert(loadfile(getFile(name)))
  local sandbox_env = setmetatable(upvalues or { }, {__index = _G})
  setfenv(chunk, sandbox_env)
  return chunk
end

function generateTests(tableOfTests)
  local tests = {}
  for what, t in pairs(tableOfTests) do
    tests[what] = t
  end
  return tests
end

local function safeCall(with, expector, methodName, args, failMsg)
  local fn = (methodName and with[methodName]) or with
  if isFunction(fn) then
    local ok, result = pcall(fn, unpack(args or {}))
    if not ok then
      expector:fail((methodName or failMsg).. ' raised an error: ' .. result)
    end
    return result
  end
end

local function doTest(name, with)
  if focussedTest and not (focussedTest == name) then
    return
  end
  local expector = Expector:new(name, with.tag)
  expector:init()
  flushKeys()

  safeCall(with, expector, 'preModuleLoad', {})

  local moduleFn = safeCall(safeLoadModule, expector, nil, { name, with.upvalues }, 'Module load')
  local moduleToTest = safeCall(moduleFn, expector, nil, { }, 'Module invocation')
  safeCall(with, expector, 'setUp', {})
  local testResult = safeCall(with, expector, 'doTest', {moduleToTest})
  local shouldBeTrue = safeCall(with, expector, 'expect', { testResult, expector, moduleToTest })
  safeCall(with, expector, 'tearDown', {})
  expector:done(shouldBeTrue)
end

function connectMockRedis(redisConfig)
  return mockRedisClient(redis, redisConfig)
end

function runTests(tests, redisConfig, overrideBaseDir)
  redis = mockRedisClient(redis, redisConfig)

  baseDir = overrideBaseDir or baseDir
  for what, _ in pairs(tests) do
    local test = tests[what]
    for _, t in ipairs(test) do
      doTest(what, t, dir)
    end
  end

  assert(Expector.noFailures, 'TEST HAS FAILURES')
end
