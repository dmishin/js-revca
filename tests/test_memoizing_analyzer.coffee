assert = require "assert"

{MemoAnalyser} = require "../scripts-src/memoizing_analyzer"
rules = 

#{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = module_cells

{xor_transposition, compose_transpositions, Rule, from_list, parse, Bits,
 NamedRules} = require "../scripts-src/rules"


describe "MemoAnalyser", ->
  it "must find 3 spatial invariant transforms (rotations) for a SingleRotate rule",->
    analyser = new MemoAnalyser NamedRules.singleRotate
    assert.equal analyser.symmetries.length, 3

  it "must find 7 (rotations*flips-1) spatial invariant transforms for a critters rule",->
    analyser = new MemoAnalyser NamedRules.critters
    assert.equal analyser.symmetries.length, 7
