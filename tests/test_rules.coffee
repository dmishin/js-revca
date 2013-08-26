assert = require "assert"
#module_cells = require "../scripts-src/cells"
#{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = module_cells
module_rules = require "../scripts-src/rules"
{Rules, Bits} = module_rules



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
  