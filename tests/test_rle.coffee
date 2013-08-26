assert = require "assert"
module_rle = require "../scripts-src/rle"

describe ("rle.remove_whitespaces(s)"), ->
  rws = module_rle.remove_whitespaces
  
  it "must work with empty str", ->
    assert.equal (rws ""), ""
  it "must leave strings without ws unchanged", ->
    assert.equal (rws "abs"), "abs"
    assert.equal (rws "hello"), "hello"
  it "must remove all kinds of space characters", ->
    assert.equal (rws "a b"), "ab"
    assert.equal (rws " a "), "a"
    assert.equal (rws "     "), ""
    assert.equal (rws "he\t\nllo"), "hello"    
    assert.equal (rws "hello \n"), "hello"    
