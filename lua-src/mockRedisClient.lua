-- Copyright © 2017 Ganchrow Scientific, SA all rights reserved
--
-- luacheck: ignore 111
-- luacheck: globals redis cjson yaml

local get_config_option = require('/getConfigOption')

return function(redis, redisConfig)

  -- redis-lua converts these command results to a boolean, but internally, they are returned as 0 or 1
  local BOOLEAN_COMMANDS = {
    exists = true,
    expire = true,
    hexists = true,
    hset = true,
    hsetnx = true,
    move = true,
    pexpire = true,
    pexpireat = true,
    persist = true,
    renamenx = true,
    sismember = true
  }

  local executionEnv = os.getenv('EXECUTION_ENVIRONMENT')
  if (executionEnv ~= 'TESTING') then
    executionEnv = 'DEVELOPMENT'
  end

  if not (type(redisConfig) == 'table') then
    local config = yaml.loadpath(redisConfig or 'configs/redis.yaml')
    redisConfig = get_config_option.get(config, executionEnv, 'mockRedis', 'host', 'port', 'auth_pass', 'db', 'flush')
  end

  if not (redisConfig.host and redisConfig.port) then
    print('Need host and port, but got: ' .. (redisConfig.host or '<NONE>') .. ':' .. (redisConfig.port or '<NONE>'))
    os.exit(1)
  end

  local client = redis.connect(redisConfig.host, redisConfig.port)
  if redisConfig.auth_pass then
    local ok, res = pcall(function() return client:auth(redisConfig.auth_pass) end)
    if not ok then
      print('CONTINUABLE ERROR -- ' .. res)
    end
  end
  if redisConfig.db then
    print('Using DB ' .. redisConfig.db)
    client:select(redisConfig.db)
  else
    print('Using DB 9')
    client:select(9)
  end
  if redisConfig.flush then
    client:flushdb()
  end

  local function invoke(cmd, ...)
    local chunk = assert(loadstring('return client:' .. cmd .. '(...)'))
    local sandbox_env = setmetatable({ client = client }, {__index = _G})
    setfenv(chunk, sandbox_env)
    return chunk(...)
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
    cmd = string.lower(cmd)

    if (cmd == 'unlink') then
      -- unlink not available in this client
      cmd = 'del';
    end
    local args = {...}
    local result
    if cmd == 'publish' then
      local channel = 'publish:' .. args[1]
      local val = args[2]
      result = invoke('lpush', channel, val)
    elseif cmd == 'hgetall' then
      local initial = invoke(cmd, ...)
      if initial then
        result = {}
        for key, val in pairs(initial) do
          table.insert(result, key)
          table.insert(result, val)
        end
      end
    elseif (cmd == 'zrangebyscore' or cmd == 'zrevrangebyscore' or cmd == 'zrevrange' or cmd == 'zrange') and
        ((type(args[4]) == 'string' and string.lower(args[4]) == 'withscores') or
         (type(args[5]) == 'string' and string.lower(args[5]) == 'withscores')) then
      local initial = invoke(cmd, ...)
      if initial then
        result = {}
        for _, val in ipairs(initial) do
          table.insert(result, val[1])
          table.insert(result, val[2])
        end
      end
    elseif (BOOLEAN_COMMANDS[cmd]) then
      local initial = invoke(cmd, ...)
      result = initial and 1 or 0
    elseif (cmd == 'hmget') then
      local builder
      if type(args[2]) == 'table' then
        builder = args[2]
      else
        builder = {}
        for i = 2,#args do
          table.insert(builder, args[i])
        end
      end
      result = invoke(cmd, args[1], builder)
    else
      result = invoke(cmd, ...)
    end

    -- uncomment for better debugging during tests
    -- print('command: ' .. cmd .. ' ' .. table.concat({...}, ' '))
    -- print('result: ' .. cjson.encode(result))
    return result
  end

  redis.log = function(msg)
    print(msg)
  end

  redis.replicate_commands = function()
    client:set('__replicate_commands_invoked__', 1)
  end
  redis.set_repl = function(arg)
    client:set('__replicate_commands_mode__', tostring(arg or 'undefined'))
  end

  return redis
end
