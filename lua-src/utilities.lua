-- Copyright © 2016 Ganchrow Scientific, SA all rights reserved
--
-- provide general-purpose utility functions for the test framework

-- compare two vectors (one-dimensional arrays) for element-by-element equality
-- a vector of booleans is acceptable but nil elements are not
local Module = {}

function Module.isFunction(thing)
  return type(thing) == 'function'
end

function Module.vectorEquals(a, b)
  if a == b then return true end
  if not a or not b or #a ~= #b then
    return false
  else
    local vecEqual = true
    for i, val in ipairs(a) do
      if val == nil or b[i] == nil or val ~= b[i] then
        vecEqual = false
        break
      end
    end
    return vecEqual
  end
end

function Module.fieldCompare(t1, t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  local bool = true
  for k, v in pairs(t1) do
    if not (Module.fieldCompare(v, t2[k])) then
      bool = false
      break
    end
  end
  return bool
end

function Module.convertToDictionary(t, valCB)
  local key
  local dict = {}
  for idx, val in ipairs(t) do
    if idx % 2 == 1 then
      key = val
    else
      if Module.isFunction(valCB) then
        val = valCB(val)
      end
      dict[key] = val
    end
  end
  return dict
end

-- This code is borrowed from
-- https://github.com/timruffles/romans/commit/b34d5a9bd9b4c449d7604455026d0fa0a8b77ed0
function Module.deepcompare(t1,t2,ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not Module.deepcompare(v1,v2) then return false end
  end
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not Module.deepcompare(v1,v2) then return false end
  end
  return true
end

function Module.toDebugString(obj)
  local t = type(obj)
  if t == 'string' then
    return obj
  elseif t == 'number' or t == 'boolean' then
    return tostring(obj)
  elseif t == 'table' then
    return cjson.encode(obj)
  elseif t == nil then
    return 'nil'
  else
    return 'unknown type'
  end
end

return Module
