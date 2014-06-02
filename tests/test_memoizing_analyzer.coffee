assert = require "assert"

{MemoAnalyser} = require "../scripts-src/memoizing_analyzer"

{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = require "../scripts-src/cells"

{xor_transposition, compose_transpositions, Rule, from_list, parse, Bits,
 NamedRules} = require "../scripts-src/rules"


describe "MemoAnalyser", ->
  it "must find 3 spatial invariant transforms (rotations) for a SingleRotate rule",->
    analyser = new MemoAnalyser NamedRules.singleRotate
    assert.equal analyser.symmetries.length, 3

  it "must find 7 (rotations*flips-1) spatial invariant transforms for a critters rule",->
    analyser = new MemoAnalyser NamedRules.critters
    assert.equal analyser.symmetries.length, 7


  it "must detect spaceship's parameters: offset, period", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern = Cells.from_rle "$2o2$2o"

    #$  
    #oo
    #$
    #$
    #oo

    result = analyser.analyse pattern
    assert result
    assert.equal result.dx, 2
    assert.equal result.dy, 0
    assert.equal result.period, 12

