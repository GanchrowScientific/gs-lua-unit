# Create lua unit tests

```lua
-- test.lua

dofile('./node_modules/gs-lua-unit/lua-src/common.lua')
-- lua setup stuff

runTests(generateTests({
  foo = {{
    tag = 'Testing file foo',
    doTest = function(fooModule)
      return fooModule.doStuff()
    end,
    expect = function(resultFromDoTest, expector, fooModule)
      -- expector has all sorts of goodies
      expector:expectStrictEqual(resultFromDoTest.result1, 'fooResult1')
      expector:expectTruthy(resultFromDoTest.result2)
      expector:expectFalsy(resultFromDoTest.result3)
      expector:expectDeepEqual(resultFromDoTest.resultObj, {foo = 1, bar = 2})
      return true -- must return true here
      -- its not required to use the expector, you can do stuff like
      -- return result and result[1].foo == 'bar'
      -- but the expector provides detailed assertion failures
    end
  }, {
    -- more tests
  }},

  bar = {{
    -- more tests
  }}
})
```

And then

```bash
lua /path/to/test.lua
```

# What are foo and bar

`foo = ...` and `bar = ...` point to files that exist in a directory with lua scripts named *foo* and *bar*.

By default, **gs-lua-unit** looks in the directory "target/test_scripts/", but this directory can also be specified with the third argument to `runTests`.

# What about [Redis](https://redis.io/)?

A redis.call method is provided for you, and works on an **active** redis.

**gs-lua-unit** looks for redis in a "redis.yaml" of the current working directory.

```yaml
# redis.yaml
mockRedis:
 host: localhost
 port: 6379
```

Redis location can also be passed as the second argument to `runTests` above

```lua
runTests(generateTests({ ... }), redisConfig)
```

