assert = require "assert"
reversible_ca = require "../scripts-src/reversible_ca"


describe "class Array2d: array of bytes", ->
  {Array2d} = reversible_ca
  it "should support creation and element access", ->
    a = new Array2d 10, 10
    a.fill 0
    for x in [0 .. 9]
      for y in [0 .. 9]
        assert.equal a.get(x,y), 0
    null
    
  it "should support element modification", ->
    a = new Array2d 10, 10
    for x in [0 .. 9]
      for y in [0 .. 9]
        a.set x, y, (x+y*10)
        
    for x in [0 .. 9]
      for y in [0 .. 9]
        axy = a.get(x,y)
        assert.equal axy, (x+y*10)
    null

  it "shoud return size", ->
    a = new Array2d 20, 10
    assert.deepEqual a.size(), [20,10]