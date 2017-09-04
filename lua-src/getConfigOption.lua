-- Copyright © 2017 Ganchrow Scientific, SA all rights reserved
--
--

-- luacheck: globals adj_env setfenv
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
        adj_env = string.gsub(k, '[.]**$', '.*')
        if string.find(env, adj_env) then
          inner_environment = config['ENVIRONMENTS'][k]
          break
        end
      end
    end
  end
  local inner_config = (inner_environment or {})[field] or {}
  for _, f in ipairs({...}) do
    table.insert(res, inner_config[f] or config[field][f])
  end
  return res
end
return M
