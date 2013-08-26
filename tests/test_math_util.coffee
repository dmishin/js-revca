assert = require "assert"
module_math_util = require "../scripts-src/math_util"

describe ("cap(a,b,x)"), ->
  {cap} = module_math_util
  it "must leave value unchanged, if it is inside the region", ->
    assert.equal 1.5, cap 1, 2, 1.5
  it "must cap value outside of region", ->
    assert.equal 2, cap 1, 2, 3
    assert.equal 1, cap 1, 2, -1    
