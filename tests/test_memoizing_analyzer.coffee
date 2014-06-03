assert = require "assert"

{MemoAnalyser} = require "../scripts-src/memoizing_analyzer"

{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = require "../scripts-src/cells"

{xor_transposition, compose_transpositions, Rule, from_list, parse, Bits,
 NamedRules} = require "../scripts-src/rules"


describe "MemoAnalyser::constructor", ->
  it "must find 3 spatial invariant transforms (rotations) for a SingleRotate rule",->
    analyser = new MemoAnalyser NamedRules.singleRotate
    assert.equal analyser.symmetries.length, 3

  it "must find 7 (rotations*flips-1) spatial invariant transforms for a critters rule",->
    analyser = new MemoAnalyser NamedRules.critters
    assert.equal analyser.symmetries.length, 7


describe "MemoAnalyser::analyse", ->
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

  it "must detect the same spaceship with the same result", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern = Cells.from_rle "$2o2$2o"

    #initial result
    result1 = analyser.analyse pattern

    #second try
    result2 = analyser.analyse pattern

    assert (result1 is result2), "Analysis must retuen the same object for the second call"

  it "must detect the same spaceship in different phases", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern1 = Cells.from_rle "$2o2$2o"
    pattern2 = Cells.from_rle "o$obo$o" #same pattern at generation 5

    #initial result
    result1 = analyser.analyse pattern1
    #second try
    result2 = analyser.analyse pattern2

    assert (result1 is result2), "Analysis must return the same object for the second call"

    
