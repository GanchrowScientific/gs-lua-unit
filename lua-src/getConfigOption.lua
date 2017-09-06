-- Copyright © 2017 Ganchrow Scientific, SA all rights reserved
--
--

local M = {}
function M.get(config, env, field, ...)
  if not next(config) then
    return
  end
  env = env or 'DEVELOPMENT'
  local res = {}
  local inner_environment
  if config['ENVIRONMENTS'] then
    inner_environment = config['ENVIRONMENTS'][env]
    if not inner_environment then
      for k, _ in pairs(config['ENVIRONMENTS']) do
        local adjEnv = string.gsub(k, '[.]**$', '.*')
        if string.find(env, adjEnv) then
          inner_environment = config['ENVIRONMENTS'][k]
          break
        end
      end
    end
  end
  local inner_config = (inner_environment or {})[field] or {}
  for _, f in ipairs({...}) do
    local value = (inner_config and inner_config[f]) or
      config[field] and config[field][f]
    if (value) then
      res[f] = value
    end
  end
  return res
end
return M
