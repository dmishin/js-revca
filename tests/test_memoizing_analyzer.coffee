assert = require "assert"

{Resolution, MemoAnalyser} = require "../scripts-src/memoizing_analyzer"

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
    assert.equal result.resolution, Resolution.HAS_PERIOD
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


  it "must detect the same spaceship, rotated", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern1 = Cells.from_rle "$2o2$2o"
    pattern2 = Cells.from_rle "obo$obo" #same pattern, rotated 90
    pattern3 = Cells.from_rle "2o2$2o"  #same pattern, rotated 180
    pattern4 = Cells.from_rle "bobo$bobo"  #same pattern, rotated 270

    #results
    result1 = analyser.analyse pattern1
    result2 = analyser.analyse pattern2
    result3 = analyser.analyse pattern3
    result4 = analyser.analyse pattern4

    assert (result1 is result2), "result1 == result2"
    assert (result1 is result3), "result1 == result3"
    assert (result1 is result4), "result1 == result4"

    
  it "must count hit number for patterns", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern1 = Cells.from_rle "$2o2$2o"
    pattern2 = Cells.from_rle "obo$obo" #same pattern, rotated 90

    result1 = analyser.analyse pattern1
    assert.equal result1.hits, 1, "must have 1 hit for the first occurence"
    #same pattern
    result1_1 = analyser.analyse pattern1
    assert.equal result1_1.hits, 2, "must have 2 hits after 2 tries"

    #same pattern, rotated
    result2 = analyser.analyse pattern2
    assert.equal result2.hits, 3, "must have 3 hits after 3 tries"

describe "MemoAnalyser::truncateTable", ->
  it "must do nothing, when max table size is big enough", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern = Cells.from_rle "$2o2$2o"
    result1 = analyser.analyse pattern
    assert.equal result1.hits, 1

    analyser.truncateTable 1000
    result2 = analyser.analyse pattern
    assert.equal result1, result2
    assert.equal result2.hits, 2
    
  it "must completely clear cache, when max table size is 0", ->
    analyser = new MemoAnalyser NamedRules.singleRotate
    pattern = Cells.from_rle "$2o2$2o"
    result1 = analyser.analyse pattern
    assert.equal result1.hits, 1

    analyser.truncateTable 0 #clear cache
    result2 = analyser.analyse pattern
    assert.ok  not (result1 is result2), "after clear cache, results must be different"    
    assert.equal result2.hits, 1
    
    