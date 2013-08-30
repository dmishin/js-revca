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


  it "should support wrapped access", ->
    a = new Array2d 10, 15
    a.fill 0
    a.set_wrapped 5, 7, 57
    a.set_wrapped 15, 19, 59
    a.set_wrapped -1, -2, 12

    assert.equal a.get(5,7), 57
    assert.equal a.get_wrapped(5,7), 57
    assert.equal a.get_wrapped(15,7), 57
    assert.equal a.get_wrapped(-5,7), 57
    assert.equal a.get_wrapped(5,22), 57
    assert.equal a.get_wrapped(5,-8), 57

    assert.equal a.get_wrapped(15, 19), 59
    assert.equal a.get_wrapped(5, 4), 59
    assert.equal a.get(5, 4), 59

    assert.equal a.get_wrapped(-1, -2), 12
    assert.equal a.get_wrapped(9, 13), 12
    
