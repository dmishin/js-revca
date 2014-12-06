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

describe "to_rle( cells_list ): convert *sorted* list of cells to RLE code", ->
  to_rle = module_rle.to_rle
  
  it "must tolerate empty data", ->
    assert.equal (to_rle []), ""
  it "must encode 1-cellers", ->
    assert.equal (to_rle [[0,0]]), "o"
    assert.equal (to_rle [[0,1]]), "$o"
    assert.equal (to_rle [[1,0]]), "bo"
    assert.equal (to_rle [[1,1]]), "$bo"
    
  it "must compress repeating characters", ->
    assert.equal (to_rle [[5,5]]), "5$5bo"
    assert.equal (to_rle [[25,35]]), "35$25bo"

    assert.equal (to_rle [[5,5],[6,5]]), "5$5b2o"
    assert.equal (to_rle [[5,5],[7,5]]), "5$5bobo"

  it "must raise error, when data is not sorted", ->
    assert.throws (-> to_rle [[5,5],[5,5]]), "Repeating cells"
    assert.throws (-> to_rle [[5,5],[4,5]]), "Non-sorted by x"
    assert.throws (-> to_rle [[5,5],[6,3]]), "Non-sorted by y"

  it "must raise error, when data is negative", ->
    assert.throws (-> to_rle [[-1,0]])
    assert.throws (-> to_rle [[-5,0]])
    assert.throws (-> to_rle [[0,-1]])
    assert.throws (-> to_rle [[-2,-2]])


  it "must encode glider", ->
    rle = "2o$obo$o"
    glider = [[0,0],[1,0],[0,1],[2,1],[0,2]]
    assert.equal (to_rle glider), rle
