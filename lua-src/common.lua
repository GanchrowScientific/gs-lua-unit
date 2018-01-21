-- Copyright © 2017 Ganchrow Scientific, SA all rights reserved
--

-- luacheck: ignore 111
-- luacheck: globals redis cjson yaml

-- Require globally
cjson = require('cjson')
yaml = require('yaml')
redis = require('redis')
bit = require('bit')

-- ensure helper modules or mocks are required over actual modules
local dir = arg[0]:match('(.*/)') or ''

-- strips out last segment of path
local kind = dir:reverse():sub(2, dir:reverse():sub(2):find('/')):reverse()
local baseDir = '/../../target/test_scripts/'
local projectPath = arg[1]
local focussedTest = arg[2]

print(dir, kind)

package.path = dir .. '?.lua;' .. dir .. '../?.lua;' .. dir .. '../../?.lua;' ..
  ((projectPath .. '/') or (dir .. '../../')) .. 'node_modules/gs-lua-unit/lua-src/?.lua;' .. package.path

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


local function doTest(name, with)
  if focussedTest and not (focussedTest == name) then
    return
  end
  local expector = Expector:new(name, with.tag)
  expector:init()
  flushKeys()

  if isFunction(with.preModuleLoad) then
    with.preModuleLoad()
  end

  local moduleFn = safeLoadModule(name, with.upvalues)
  local moduleToTest = moduleFn()

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
