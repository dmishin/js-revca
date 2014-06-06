assert = require "assert"
{Array2d, MargolusNeighborehoodField} = require "../scripts-src/reversible_ca"
rules = require "../scripts-src/rules"
{Cells} = require "../scripts-src/cells"

describe "class Array2d: array of bytes", ->
  it "should support creation and element access", ->
    a = new Array2d 10, 10
    a.fill 0
    for x in [0 .. 9]
      for y in [0 .. 9]
        assert.equal a.get(x,y), 0
    null
    
  it "should support element modification", ->
    a = new Array2d 10, 10
    for x in [0 .. 9]
      for y in [0 .. 9]
        a.set x, y, (x+y*10)
        
    for x in [0 .. 9]
      for y in [0 .. 9]
        axy = a.get(x,y)
        assert.equal axy, (x+y*10)
    null

  it "shoud return size", ->
    a = new Array2d 20, 10
    assert.deepEqual a.size(), [20,10]


  it "should support wrapped access", ->
    a = new Array2d 10, 15
    a.fill 0
    a.set_wrapped 5, 7, 57
    a.set_wrapped 15, 19, 59
    a.set_wrapped -1, -2, 12

    assert.equal a.get(5,7), 57
    assert.equal a.get_wrapped(5,7), 57
    assert.equal a.get_wrapped(15,7), 57
    assert.equal a.get_wrapped(-5,7), 57
    assert.equal a.get_wrapped(5,22), 57
    assert.equal a.get_wrapped(5,-8), 57

    assert.equal a.get_wrapped(15, 19), 59
    assert.equal a.get_wrapped(5, 4), 59
    assert.equal a.get(5, 4), 59

    assert.equal a.get_wrapped(-1, -2), 12
    assert.equal a.get_wrapped(9, 13), 12
    

make_empty = -> new MargolusNeighborehoodField( new Array2d 4, 4 )

describe "MargolusNeighborehoodField.field.put_cells", ->
  it "must get same cells as put", ->
    cells = [[0,0],[1,0],[3,2]]
    f = make_empty()
    f.field.put_cells cells,0,0
    assert.deepEqual (f.field.get_cells 0,0, 4,4), cells
  it "must work with empty list", ->
    f = make_empty()
    f.field.put_cells [],0,0
    assert.deepEqual (f.field.get_cells 0,0,4,4), []
  it "must support putting by coordinates", ->
    f = make_empty()
    cells = [[0,0],[1,0],[1,2]]
    f.field.put_cells cells, 1, 0
    assert.deepEqual (f.field.get_cells 0,0,4,4), [[1,0],[2,0],[2,2]]
    
describe "MargolusNeighborehoodField.apply_xor", ->
  cells = [[0,0],[1,0],[3,2]]
  make_nonempty = ->
    f = make_empty()
    f.field.put_cells cells,0,0
    f
    
  it "must not change field, when XORiing with 0", ->
    f = make_nonempty()
    f.apply_xor 0
    assert.deepEqual (f.field.get_cells 0,0,4,4), cells
  it "must change field when XORing with non-zero", ->
    f = make_nonempty()
    f.apply_xor 1
    #  [1 0]
    #  [0 0]
    #   XOR
    #  [1100]
    #  [0000]
    #  [0001]
    #  [0000]

    #  [0110]
    #  [0000]
    #  [1011]
    #  [0000]

    cells1 = [[1,0],[2,0],[0,2],[2,2],[3,2]]
    assert.deepEqual (f.field.get_cells 0,0,4,4), cells1
  it "must return to the original, when XORed twice", ->
    f = make_nonempty()
    f.apply_xor 3
    assert.notDeepEqual (f.field.get_cells 0,0,4,4), cells
    f.apply_xor 3
    assert.deepEqual (f.field.get_cells 0,0,4,4), cells
    
  it "must correctly put bits of the value", ->
    f = make_nonempty()
    f.apply_xor 2
    #  [0 1]
    #  [0 0]
    #   XOR
    #  [1100]
    #  [0000]
    #  [0001]
    #  [0000]

    #  [1001]
    #  [0000]
    #  [0100]
    #  [0000]
    cells1 = [[0,0],[3,0],[1,2]]
    assert.deepEqual (f.field.get_cells 0,0,4,4), cells1
  it "must work when phase is not 0", ->
    f = make_nonempty()
    f.phase ^= 1
    f.apply_xor 2
    #  [0 1]
    #  [0 0]
    #   XOR
    #  [1 10 0]
    #  [0 00 0]
    #  [0 00 1]
    #  [0 00 0]
    # 
    #  [1 10 0]
    #  [1 01 0]
    #  [0 00 1]
    #  [1 01 0]

    cells1 = [[0,0],[1,0],[0,1],[2,1],[3,2],[0,3],[2,3]]
    assert.deepEqual (f.field.get_cells 0,0,4,4), cells1

describe "Array2d::pick_pattern_at x, y, x0, y0, erase=false, range = 4, max_size=null", ->
  empty_array = -> new Array2d 10, 10
  
  it "must pick simple figures of 1 cell", ->
    arr = empty_array()
    arr.put_cells [[5,5]]

    picked = arr.pick_pattern_at 5,5,0,0
    assert.deepEqual picked, [[5,5]]
    assert.equal arr.get(5,5), 1, "picking by default should not change field"

  it "must pick ffigure of more than 1 cell", ->

    cells = [[5,5],[5,6],[6,5]]
    Cells.sortXY cells
    arr = empty_array()
    arr.put_cells cells

    picked = arr.pick_pattern_at 5,5,0,0
    Cells.sortXY picked
    assert.deepEqual picked, cells
    assert.equal arr.get(5,5), 1, "picking by default should nto change field"

  it "must return the same, if figure is smaller then maximum size", ->
    cells = [[5,5],[5,6],[6,5]]
    Cells.sortXY cells
    arr = empty_array()
    arr.put_cells cells

    picked = arr.pick_pattern_at 5,5,0,0, false, 4, 10 #10 is size limitation
    Cells.sortXY picked
    assert.deepEqual picked, cells
    assert.equal arr.get(5,5), 1, "picking by default should nto change field"

  it "must return smaller number of cells, when size limitation is specified", ->
    cells = [[5,5],[5,6],[6,5]]
    Cells.sortXY cells
    arr = empty_array()
    arr.put_cells cells

    picked = arr.pick_pattern_at 5,5,0,0, false, 4, 2 #2 is size limitation - smaller than figure of 3 cells


    cell_in_list = ([x,y], cells) ->
      for [x1,y1] in cells
        if x1 is x and y1 is y
          return true
    false

    assert.equal picked.length, 2
    for xy in picked
      assert cell_in_list xy, cells, "Cell #{JSON.stringify xy} must be in the original figure #{JSON.stringify cells}"


##Put pattern, given as a list of strings. '#' is for one
makeArray2d = (width, height, rows) ->
  array2d = new Array2d width, height
  for row, y in rows
    for x in [0 ... row.length] by 1
      array2d.set x,y, (if row.charAt(x) is '#' then 1 else 0)
  return array2d

describe "makeArray2d", ->
  it "must create Array2d with given pattern", ->
    pattern = [ '#####.',
                '##..#.',
                '.###..',
                '.....#']
    arr = makeArray2d 6, 4, pattern
    testCell = (x,y,v) ->
        got = arr.get(x,y)
        assert.equal got, v, "Array[#{x},#{y}] = #{got} != #{v}"
    testCell 0,0,1
    testCell 1,0,1
    testCell 2,0,1
    testCell 5,0,0

    testCell 0,1,1
    testCell 0,2,0
    testCell 0,3,0

    testCell 5,3,1
    testCell 4,3,0
    testCell 5,2,0


describe "MargolusNeighborehoodField.transform rule", ->
  rule = rules.from_list [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15] #single rotation rule
        
  it "must leave empty field empty, when rule is single rotation", ->
    cells = new Array2d 4, 4
    cells.fill 0
    field = new MargolusNeighborehoodField cells
    field.transform rule
    
    cellsExpected = new Array2d 4, 4
    cellsExpected.fill 0

    assert.deepEqual cells, cellsExpected
  it "must transform pattern in the phase 0", ->
    #letters only designate blocks, they correspond to 0 too.
    initialPattern = [ 'a#cc..',
                       'aa##..',
                       '..#b..',
                       '..bb..',
                       '....dd',
                       '....d#']
    expectedPattern =[ 'aacc..',
                       'a###..',
                       '..b#..',
                       '..bb..',
                       '....dd',
                       '....#d']

    cells = makeArray2d 6,6, initialPattern
    field = new MargolusNeighborehoodField cells
    field.transform rule
    assert.deepEqual field.field, makeArray2d(6,6,expectedPattern)

  it "must transform pattern in the phase 1, including blocks across the edge", ->
    initialPattern = [ 'a#d..a',
                       '.b##c.',
                       '.b#cc.',
                       '......',
                       '......',
                       'add..#']
                
    expectedPattern =[ 'add..a',
                       '.b#c#.',
                       '.b#cc.',
                       '......',
                       '......',
                       '##d..a']
                
    cells = makeArray2d 6,6, initialPattern
    field = new MargolusNeighborehoodField cells
    field.phase = 1 #update phase
    field.transform rule
    assert.deepEqual field.field, makeArray2d(6,6,expectedPattern)
    
    
describe "MargolusNeighborehoodField::snap_below", ->
  it "must return even number <= x, if field phase is 0", ->
    fld = new MargolusNeighborehoodField new Array2d 4, 4
    assert.equal fld.phase, 0
    assert.equal fld.snap_below(0), 0
    assert.equal fld.snap_below(1), 0
    assert.equal fld.snap_below(2), 2
    assert.equal fld.snap_below(3), 2
    assert.equal fld.snap_below(-1), -2
    assert.equal fld.snap_below(-2), -2
    assert.equal fld.snap_below(-1000), -1000
            
  it "must return odd number <= x, if field phase is 1", ->
    fld = new MargolusNeighborehoodField new Array2d 4, 4
    fld.phase = 1
    assert.equal fld.snap_below(0), -1
    assert.equal fld.snap_below(1), 1
    assert.equal fld.snap_below(2), 1
    assert.equal fld.snap_below(3), 3
    assert.equal fld.snap_below(-1), -1
    assert.equal fld.snap_below(-2), -3
    assert.equal fld.snap_below(-1000), -1001
    assert.equal fld.snap_below(1000), 999

    
describe "MargolusNeighborehoodField::snap_upper", ->
  it "must return even number >= x, if field phase is 0", ->
    fld = new MargolusNeighborehoodField new Array2d 4, 4
    assert.equal fld.phase, 0
    assert.equal fld.snap_upper(0), 0
    assert.equal fld.snap_upper(1), 2
    assert.equal fld.snap_upper(2), 2
    assert.equal fld.snap_upper(3), 4
    assert.equal fld.snap_upper(-1), 0
    assert.equal fld.snap_upper(-2), -2
    assert.equal fld.snap_upper(-1000), -1000
            
  it "must return odd number <= x, if field phase is 1", ->
    fld = new MargolusNeighborehoodField new Array2d 4, 4
    fld.phase = 1
    assert.equal fld.snap_upper(0), 1
    assert.equal fld.snap_upper(1), 1
    assert.equal fld.snap_upper(2), 3
    assert.equal fld.snap_upper(3), 3
    assert.equal fld.snap_upper(-1), -1
    assert.equal fld.snap_upper(-2), -1
    assert.equal fld.snap_upper(-3), -3
    assert.equal fld.snap_upper(-1000), -999
    assert.equal fld.snap_upper(1000), 1001

    
