assert = require "assert"
#module_cells = require "../scripts-src/cells"
#{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = module_cells
module_rules = require "../scripts-src/rules"
{xor_transposition, compose_transpositions, Rules, Bits} = module_rules



describe "Rules.from_list, to_list", ->
  it "must restore the same list",->
    rul = [0..15]
    rul1 = Rules.to_list Rules.from_list rul
    assert.deepEqual rul, rul1

describe "Rules.parse(str, separator)", ->
  it "must parse with comma by default", ->
    s = "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0"
    r = Rules.parse s
    assert.deepEqual (Rules.to_list r), [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]

  it "must ignore whitespace and leading zeros", ->
    s = " 01,  02,\t3,4,5,6,7,8,9,   10\n,011,12,13,14,15,0"
    r = Rules.parse s
    assert.deepEqual (Rules.to_list r), [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]
    
  it "must raise an exception when rule is not complete", ->
    s = "1,2,3"
    assert.throws -> Rules.parse s
  it "must support other separators", ->
    s = " 01;  02;\t3;4;5;6;7;8;9;   10\n;011;12;13;14;15;0"
    r = Rules.parse s, ";"
    assert.deepEqual (Rules.to_list r), [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]

describe "compose_transpositions(t1, t2)", ->
  iden = [0..15]
  shift = Rules.to_list Rules.parse "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0"
  shift2 = Rules.to_list Rules.parse "2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1"
  reverse = [15..0]
  it "must work with identity transposition", ->
    assert.deepEqual (compose_transpositions iden, iden), iden, "iden x iden"
    assert.deepEqual (compose_transpositions iden, shift), shift, "iden x shift"
    assert.deepEqual (compose_transpositions shift, iden), shift, "shift x iden"
  it "must work with shift-by-1 transformation", ->
    assert.deepEqual (compose_transpositions shift, shift), shift2
  it "must give identity for squared order-reverseion transposition", ->
    assert.deepEqual (compose_transpositions reverse, reverse), iden
  it "applies transpositions in argument order: first t1 then t2", ->
    # 1 -> 2; 2 -> 1
    t1 = Rules.to_list Rules.parse "0,2,1,3,4,5,6,7,8,9,10,11,12,13,14,15"
    # 2 -> 3; 3 -> 2
    t2 = Rules.to_list Rules.parse "0,1,3,2,4,5,6,7,8,9,10,11,12,13,14,15"

    # 1 -> 3; 2 -> 1; 3 -> 2
    t12 = Rules.to_list Rules.parse "0,3,1,2,4,5,6,7,8,9,10,11,12,13,14,15"
    # 1 -> 2; 2 -> 3; 3 -> 1
    t21 = Rules.to_list Rules.parse "0,2,3,1,4,5,6,7,8,9,10,11,12,13,14,15"
    assert.deepEqual (compose_transpositions t1, t2), t12
    assert.deepEqual (compose_transpositions t2, t1), t21
    
 describe "xor_transposition(x)", ->
  iden = [0..15]
  it "must return identity for XOR-ing with zero", ->
    assert.deepEqual xor_transposition(0), iden
  it "must transpose odd with even for x=1", ->
    assert.deepEqual xor_transposition(1), [1,0,3,2,5,4,7,6,9,8,11,10,13,12,15,14]
    
  it "compose xort(x1), xort(x2) === xort( x1 ^ x2 )", ->
    test = (x1,x2) ->
      assert.deepEqual compose_transpositions(xor_transposition(x1), xor_transposition(x2)), xor_transposition(x1 ^ x2)
    test 0, 0
    test 5, 7
    test 7, 5
    test 13, 15
    test 4, 9