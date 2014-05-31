assert = require "assert"
module_math_util = require "../scripts-src/math_util"

describe ("cap(a,b,x)"), ->
  {cap} = module_math_util
  it "must leave value unchanged, if it is inside the region", ->
    assert.equal 1.5, cap 1, 2, 1.5
  it "must cap value outside of region", ->
    assert.equal 2, cap 1, 2, 3
    assert.equal 1, cap 1, 2, -1    

describe ("div2(x)"), ->
  {div2} = module_math_util
  it "must divide even positive values by 2", ->
    assert.equal 0, div2(0)
    assert.equal 1, div2(2)
    assert.equal 2, div2(4),
    assert.equal 500, div2(1000)
  it "must divide even negative values by 2 too", ->
    assert.equal -1, div2(-1)
    assert.equal -2, div2(-4)
    assert.equal -500, div2(-1000)
  it "must round down, when dividing positive odd values", ->
    assert.equal 0, div2(1)
    assert.equal 1, div2(3)
    assert.equal 100, div2(201)
  it "must round down (to bigger absolute values), when dividing negative odd values", ->
    assert.equal -1, div2(-1)
    assert.equal -2, div2(-3)
    assert.equal -101, div2(-201)


describe ("mod2(x)"), ->
  {mod2} = module_math_util
  it "must return 1 or 0 for positive values", ->
    assert.equal 0, mod2(0)
    assert.equal 1, mod2(1)
    assert.equal 0, mod2(2)
    assert.equal 1, mod2(3)

  it "must return 1 or 0 for NEGATIVE values", ->
    assert.equal 0, mod2(0)
    assert.equal 1, mod2(-1)
    assert.equal 0, mod2(-2)
    assert.equal 1, mod2(-3)

