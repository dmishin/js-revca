assert = require "assert"
{Array2d, MargolusNeighborehoodField} = require "../scripts-src/reversible_ca"
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
