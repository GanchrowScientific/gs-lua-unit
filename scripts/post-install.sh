#!/bin/bash

PROJECT_PATH="$(dirname $0)/../"

. ./scripts/lua-setup

echo Running luacheck
luacheck `find lua* -name *.lua`
LUA_LINTING=$?


exit $(( $LUA_LINTING ))
