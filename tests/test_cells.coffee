assert = require "assert"
module_cells = require "../scripts-src/cells"
{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = module_cells
module_rules = require "../scripts-src/rules"
{Bits} = module_rules
# mocha tests/test-math-utils.coffee --compilers coffee:coffee-script

describe "Cells.areEqual(f1, f2)", ->
  it "must be true, when cell lists are equal", ->
    assert.ok Cells.areEqual [], []
    assert.ok Cells.areEqual [[1,1]], [[1,1]]
    assert.ok Cells.areEqual [[1,1],[2,3]], [[1,1],[2,3]]
  it "must be false, when cell lists are different", ->
    assert.ok not Cells.areEqual([], [[0,1]])
    assert.ok not Cells.areEqual([[0,1]], [])
    assert.ok not Cells.areEqual [[1,1],[2,3]], [[1,1],[2,4]]
    assert.ok not Cells.areEqual [[1,1],[2,3]], [[1,1],[3,3]]

describe "Cells.sortXY(fig)", ->
  it "must inplace sort cell list, first by y, then by x", ->
    cells = [[1,0],[0,1],[0,0],[1,1]]
    cells_s= [[0,0],[1,0],[0,1],[1,1]]

    assert.deepEqual (Cells.sortXY cells), cells_s
    assert.deepEqual cells, cells_s, "Check that sort was inplace"
  it "must tolerate empty list", ->
    cells = []
    assert.deepEqual (Cells.sortXY cells), []
    assert.deepEqual cells, []

describe "Cells.bounds(fig)", ->
  it "must return bounds of a cell list, inclusive: [x0,y0,x1,y1]", ->
    cells = [[1,0],[0,1],[0,0],[1,1], [-1,-2], [2,3]]
    bnds = Cells.bounds cells
    assert.deepEqual bnds, [-1, -2, 2, 3]
  it "must tolerate empty list", ->
    bnds = Cells.bounds []
    assert.deepEqual bnds, [0,0,0,0]

describe "Cells.transform(fig, tfm): transform cell coordinates relative to point (0.5,0.5) and *normalize* result", ->
  cells = [[0,0],[1,2]]
  cells_text = JSON.stringify cells
  it "must work with identity transform in #{cells_text}", ->
    t = [1,0,0,1]
    assert.deepEqual  (Cells.transform cells, t), [[0,0],[1,2]]
  it "must flip x relative to 0.5, preserving phase in #{cells_text}", ->
    t = [-1,0,0,1]
    expected = [[1,0],[0,2]]
    assert.deepEqual  (Cells.transform cells, t), expected
  it "must flip y relative to 0.5, preserving phase in #{cells_text}", ->
    t = [1,0,0,-1]
    expected = [[1,1],[0,3]]
    assert.deepEqual  (Cells.transform cells, t), expected
  it "must rotate cw, presering phase in #{cells_text}", ->
    t = [0,1,-1,0]
    expected = [[2,0],[0,1]]
    assert.deepEqual  (Cells.transform cells, t), expected
  it "must rotate ccw, presering phase in #{cells_text}", ->
    t = [0,-1,1,0]
    expected = [[3,0],[1,1]]
    assert.deepEqual  (Cells.transform cells, t), expected



describe "Cells.parse_rle( rle_string ) parse standard RLE string into list of cells", ->
  it "must tolerate empty RLE", ->
    assert.deepEqual (Cells.from_rle ""), []
  it "must decode simple RLEs", ->
    rle = "o"
    assert.deepEqual (Cells.from_rle rle), [[0,0]]
    rle = "3o"
    assert.deepEqual (Cells.from_rle rle), [[0,0],[1,0],[2,0]]
    rle = "bo"
    assert.deepEqual (Cells.from_rle rle), [[1,0]]
    rle = "$o"
    assert.deepEqual (Cells.from_rle rle), [[0,1]]
    rle = "$bo"
    assert.deepEqual (Cells.from_rle rle), [[1,1]]

  it "must ignore trailing whitespaces", ->
    rle = "$"
    assert.deepEqual (Cells.from_rle rle), []
    rle = "b"
    assert.deepEqual (Cells.from_rle rle), []
    rle = "$$2b3$bb"
    assert.deepEqual (Cells.from_rle rle), []
    rle = "$b"
    assert.deepEqual (Cells.from_rle rle), []
    rle = "o$"
    assert.deepEqual (Cells.from_rle rle), [[0,0]]

  it "must decode a glider figure", ->
    rle = "2o$obo$o"
    glider = [[0,0],[1,0],[0,1],[2,1],[0,2]]
    assert.deepEqual (Cells.from_rle rle), glider

  it "must repeat counts, bigger than 10", ->
    rle = "20$30bo"
    assert.deepEqual (Cells.from_rle rle), [[30, 20]]

describe "Cells.to_rle( cells_list ): convert *sorted* list of cells to RLE code", ->
  it "must tolerate empty data", ->
    assert.equal (Cells.to_rle []), ""
  it "must encode 1-cellers", ->
    assert.equal (Cells.to_rle [[0,0]]), "o"
    assert.equal (Cells.to_rle [[0,1]]), "$o"
    assert.equal (Cells.to_rle [[1,0]]), "bo"
    assert.equal (Cells.to_rle [[1,1]]), "$bo"
    
  it "must compress repeating characters", ->
    assert.equal (Cells.to_rle [[5,5]]), "5$5bo"
    assert.equal (Cells.to_rle [[25,35]]), "35$25bo"

    assert.equal (Cells.to_rle [[5,5],[6,5]]), "5$5b2o"
    assert.equal (Cells.to_rle [[5,5],[7,5]]), "5$5bobo"

  it "must raise error, when data is not sorted", ->
    assert.throws (-> Cells.to_rle [[5,5],[5,5]]), "Repeating cells"
    assert.throws (-> Cells.to_rle [[5,5],[4,5]]), "Non-sorted by x"
    assert.throws (-> Cells.to_rle [[5,5],[6,3]]), "Non-sorted by y"

  it "must raise error, when data is negative", ->
    assert.throws (-> Cells.to_rle [[-1,0]])
    assert.throws (-> Cells.to_rle [[-5,0]])
    assert.throws (-> Cells.to_rle [[0,-1]])
    assert.throws (-> Cells.to_rle [[-2,-2]])


  it "must encode glider", ->
    rle = "2o$obo$o"
    glider = [[0,0],[1,0],[0,1],[2,1],[0,2]]
    assert.equal (Cells.to_rle glider), rle

describe "Cells.find( cells, point )", ->
  fnd = Cells.find
  it "must return first index", ->
    fig = [[0,0],[1,1],[2,1],[5,6]]
    assert.equal 0, fnd fig, [0,0]
    assert.equal 1, fnd fig, [1,1]
    assert.equal 2, fnd fig, [2,1]
    assert.equal 3, fnd fig, [5,6]
    assert.equal null, fnd fig, [0,1]
    assert.equal null, fnd fig, [1,0]
  it "must tolerate empty list", ->
    assert.equal null, fnd [], [0,0]
    assert.equal null, fnd [], [1,0]


describe "transformMatrix2BitBlockMap( tfm )", ->
  t2b = module_cells.transformMatrix2BitBlockMap
  it "must return identity transposition, when affine transform is identity too", ->
    rule = t2b [1,0,0,1]
    assert.deepEqual rule, [0..15]

  it "must return rotation transform, when rotation matrix is given", ->
    rule = t2b [0,-1,1,0]
    expected = (Bits.rotate x for x in [0..15])
    assert.deepEqual rule, expected
    
  it "must return flip transform, when flip matrix is given", ->
    rule = t2b [-1,0,0,1]
    expected = (Bits.flip_h x for x in [0..15])
    assert.deepEqual rule, expected

describe "getDualTransform( rule )", ->
  {getDualTransform} = module_cells
  it "must return one of flips (hrz or vrt) for the single-rotation rule", ->
    [name, tfm, blockTfm] = getDualTransform module_rules.NamedRules.singleRotate
    assert.ok (name in ["flipx", "flipy", "flipxy"]), "Name is #{name}, but must be one of flipXX"

  it "must return identity transform for the trivial non-changing rule", ->
    rule = [0..15]
    [name, tfm, blockTfm] = getDualTransform rule
    assert.equal name, "iden"
    assert.deepEqual tfm, [1,0,0,1]
    assert.deepEqual blockTfm, [0..15]

describe "Cells.getDualSpaceship( sship, rule, dx, dy) -> (sship', dx', dy')", ->
  it "must work for the single-rotation rule", ->
    rule = module_rules.NamedRules.singleRotate
    figure = Cells.from_rle "3o$o$bo" #Conway glider
    expectedDualRle = "2bo$obo$b2o"
    dx = dy = 1
    [dualFigure, dx1, dy1] = Cells.getDualSpaceship figure, rule, dx, dy
    assert.equal dx1, 1
    assert.equal dy1, 1
    assert.equal Cells.to_rle(dualFigure), expectedDualRle
