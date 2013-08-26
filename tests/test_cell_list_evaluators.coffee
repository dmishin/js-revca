assert = require "assert"
module_cells = require "../scripts-src/cells"
{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = module_cells



describe "splitFigure( rule, figure, steps): separate non-interacting sub-figures", ->
  #Single rotation rule.
  rule = [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]
  it "must work with simple P12 glider o$obo$o", ->
    fig = Cells.from_rle "o$obo$o"
    groups = splitFigure rule, fig, 12
    assert.equal groups.length, 1, "Must have single group"

    grp0 = Cells.normalize groups[0]
    assert.deepEqual grp0, fig

  it "must separate a triple of P12 gliders: $bobo$bo5b2o$2bo$7b2o2$3bo2$3b2o$3bo", ->
    fig = Cells.from_rle "$bobo$bo5b2o$2bo$7b2o2$3bo2$3b2o$3bo"
    groups = splitFigure rule, fig, 12
    assert.equal groups.length, 3, "Must have 3 sub-group"
    rles = ((Cells.to_rle Cells.normalize g) for g in groups)

    expected1 = "$bobo$bo$2bo"
    expected2 = "b2o2$b2o"
    expected3 = "bo2$b2o$bo"

    rles_text = rles.join(" ")
    assert.ok (expected1 in rles), "Top glider must be present in #{rles_text}"
    assert.ok (expected2 in rles), "Right glider must be present in #{rles_text}"
    assert.ok (expected3 in rles), "Bottom glider must be present in #{rles_text}"


describe "evalueateCellList( rule, figure, phase ): evaluate figure, given by a cell list", ->
  #Single rotation rule.
  rule = [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]
  it "must tolerate empty list", ->
    out = evaluateCellList rule, [], 0
    assert.deepEqual out, []
    out = evaluateCellList rule, [], 1
    assert.deepEqual out, []
  it "must work with simple 1-cellers", ->
    fig0 = [[0,0]]
    fig1 = evaluateCellList rule, fig0, 0
    assert.deepEqual fig1, [[1,0]]
    fig2 = evaluateCellList rule, fig1, 1
    assert.deepEqual fig2, [[1,-1]]
    fig3 = evaluateCellList rule, fig2, 0
    assert.deepEqual fig3, [[0,-1]]
    fig4 = evaluateCellList rule, fig3, 1
    assert.deepEqual fig4, [[0,0]]
    
  it "must successfully evaluate a simple glider", ->
    glider = Cells.from_rle "o$obo$o" #period 12 glider
    fig = glider
    for i in [0...12]
      fig = evaluateCellList rule, fig, i%2
    glider1 = Cells.sortXY fig
    assert.deepEqual( Cells.offset(glider, 2, 0), glider1 )
    
describe "evaluateLabelledCellList( rule, figure, phase ): evaluate figure, given by a cell list", ->
  #Single rotation rule.
  rule = [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]
  it "must tolerate empty list", ->
    out = evaluateCellList rule, [], 0
    assert.deepEqual out, []
    out = evaluateCellList rule, [], 1
    assert.deepEqual out, []
  it "must work with simple 1-cellers", ->
    fig0 = [[0,0, 42]] #42 is label
    fig1 = evaluateLabelledCellList rule, fig0, 0
    assert.deepEqual fig1, [[1,0,42]]
    fig2 = evaluateLabelledCellList rule, fig1, 1
    assert.deepEqual fig2, [[1,-1,42]]
    fig3 = evaluateLabelledCellList rule, fig2, 0
    assert.deepEqual fig3, [[0,-1,42]]
    fig4 = evaluateLabelledCellList rule, fig3, 1
    assert.deepEqual fig4, [[0,0,42]]

  it "must successfully evaluate a simple glider", ->
    glider = Cells.from_rle "o$obo$o" #period 12 glider
    fig = ([x,y,42] for [x,y] in glider)
    for i in [0...12]
      fig = evaluateLabelledCellList rule, fig, i%2
    glider1 = ([x,y] for [x,y,lab] in fig)
    glider1 = Cells.sortXY glider1
    assert.deepEqual( Cells.offset(glider, 2, 0), glider1 )