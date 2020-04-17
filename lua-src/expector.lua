-- Copyright © 2017 Ganchrow Scientific, SA all rights reserved
--

local utils = require('/utilities')

local Expector = { testStarted = {}, noFailures = true }

function Expector:new(name, tag)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.failures = {}
  o.name = name
  o.tag = tag
  return o
end

function Expector:init()
  if not self.testStarted[self.name] then
    self.testStarted[self.name] = true
    print('')
    print('Testing ' .. self.name)
    print('---------------------------')
  end
end

function Expector:expectStrictEqual(...)
  local msg, expected, actual = unpack({...})
  local numberOfArgs = select('#', ...)

  if numberOfArgs < 2 or numberOfArgs > 3 then
    table.insert(self.failures, msg .. ' FAILED ' ..
    'Wrong number of arguments for expectStrictEqual')
    return
  end

  if numberOfArgs == 2 then
    actual = expected
    expected = msg
    msg = 'Checking strict equality'
  end

  if expected ~= actual then
    table.insert(self.failures, msg .. ' FAILED ' ..
      utils.toDebugString(expected) .. ' ~= ' .. utils.toDebugString(actual)
    )
    table.insert(self.failures, debug.traceback())
  end
end

function Expector:expectDeepEqual(...)
  local msg, expected, actual = unpack({...})
  local numberOfArgs = select('#', ...)

  if numberOfArgs < 2 or numberOfArgs > 3 then
    table.insert(self.failures, msg .. ' FAILED ' ..
    'Wrong number of arguments for expectDeepEqual')
    return
  end

  if numberOfArgs == 2 then
    actual = expected
    expected = msg
    msg = 'Checking deep equality'
  end

  if not utils.deepcompare(expected, actual, true) then
    table.insert(self.failures, msg .. ' FAILED ' ..
      utils.toDebugString(expected) .. ' deep equal ' .. utils.toDebugString(actual)
    )
    table.insert(self.failures, debug.traceback())
  end
end

function Expector:expectFieldEqual(...)
  local msg, expected, actual = unpack({...})
  if select('#', ...) == 2 then
    actual = expected
    expected = msg
    msg = 'Checking field equality'
  end
  if not utils.fieldCompare(expected, actual) then
    table.insert(self.failures, msg .. ' FAILED ' ..
      utils.toDebugString(expected) .. ' field Equal ' .. utils.toDebugString(actual)
    )
    table.insert(self.failures, debug.traceback())
  end
end

function Expector:expectTruthy(...)
  local msg, actual = unpack({...})
  if select('#', ...) == 1 then
    actual = msg
    msg = 'Checking truthiness'
  end

  if not actual then
    table.insert(self.failures, msg .. ' FAILED expected truthy, got ' .. utils.toDebugString(actual))
    table.insert(self.failures, debug.traceback())
  end
end

function Expector:expectFalsy(...)
  local msg, actual = unpack({...})
  if select('#', ...) == 1 then
    actual = msg
    msg = 'Checking falsiness'
  end

  if actual then
    table.insert(self.failures, msg .. ' FAILED expected falsy, got ' .. utils.toDebugString(actual))
    table.insert(self.failures, debug.traceback())
  end
end

function Expector:fail(msg)
  table.insert(self.failures, msg .. ' FAILED ')
  table.insert(self.failures, debug.traceback())
end

function Expector:done(finalValue)
  local tag = utils.toDebugString(self.tag or '--')
  local name = utils.toDebugString(self.name or '--')
  local additionalMessage = utils.toDebugString(self.message or '')
  local finalMessage = name .. ' ' .. tag .. ' ' .. additionalMessage
  local isSuccess = finalValue and #self.failures == 0
  if isSuccess then
    finalMessage = 'success -- ' .. finalMessage
  else
    finalMessage = '!!FAILURE!! -- ' .. finalMessage .. ' '
  end
  print(finalMessage)
  if #self.failures > 0 then
    for _, err in ipairs(self.failures) do
      print('  ' .. err)
    end
  end

  Expector.noFailures = Expector.noFailures and isSuccess
end

return Expector
