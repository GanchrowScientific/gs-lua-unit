#!/bin/bash

PROJECT_PATH="$(dirname $0)/../"
FILES=$(/bin/bash -c "find {src,test,integration-test} -follow -name *.ts")
echo $FILES

cd $PROJECT_PATH
mkdir -p target/configs

echo Installing in `pwd`

echo Running tsc...
node_modules/.bin/tsc
COMPILATION=$?

echo Running tslint..
node_modules/.bin/tslint $FILES
TS_LINTING=$?

echo Running luacheck
luacheck `find lua* -name *.lua`
LUA_LINTING=$?


echo Copying compiled source to helpers folder
mkdir helpers
cp -r target/dist/src/* ./helpers
cp -r configs target/dist

echo Fixing the source maps
SOURCE_MAPS=0
for f in $(find ./helpers/ -type f -name '*.js.map');
do
  echo "Fix: $f";
  sed -i -e s_\\.\\./\\.\\./__ $f
  (( SOURCE_MAPS += $? ))
done

exit $(( $COMPILATION + $TS_LINTING + $LUA_LINTING ))
