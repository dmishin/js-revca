assert = require "assert"
{Cells} = require "../scripts-src/cells"
{from_list} = require "../scripts-src/rules"


single_rot = from_list [[0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]]
critters = from_list [[15,14,13,3,11,5,6,1,7,9,10,2,12,4,8,0]]

describe "Cells.analyze() : analyze patterns", ->
  it "must detect block pattern correctly", ->
    pattern = Cells.from_rle "b2o$b2o"
    result = Cells.analyze pattern, single_rot
    assert result
    assert.equal result.dx, 0
    assert.equal result.dy, 0
    #visually, it is static, but phases are not equal.
    assert.equal result.period, 2

  it "must detect 1-cell pattern correctly", ->
    pattern = [[0,0]]
    result = Cells.analyze pattern, single_rot
    assert result
    assert.equal result.dx, 0
    assert.equal result.dy, 0
    #visually, it is static, but phases are not equal.
    assert.equal result.period, 4


  it "must detect light orthogonal spaceship correctly", ->
    pattern = Cells.from_rle "$2o2$2o"
    result = Cells.analyze pattern, single_rot
    assert result
    assert.equal result.dx, 2
    assert.equal result.dy, 0
    assert.equal result.period, 12


  it "must detect light diagonal spaceship correctly", ->
    pattern = Cells.from_rle "2bo$obo$o"
    result = Cells.analyze pattern, single_rot
    assert result
    assert.equal result.dx, 2
    assert.equal result.dy, 2
    assert.equal result.period, 48

  it "must detect long-period diagonal spaceship correctly", ->
    pattern = Cells.from_rle "o$o2$o$o"
    result = Cells.analyze pattern, single_rot
    assert result
    assert.equal result.dx, 2
    assert.equal result.dy, 2
    assert.equal result.period, 368
                        
  it "must successfully analyze some big spaceship", ->
    pattern = Cells.from_rle "b2obobo$4bo$4bo$4bo$6bo"
    result = Cells.analyze pattern, single_rot
    assert result
    assert.equal result.dx, 4
    assert.equal result.dy, 0
    assert.equal result.period, 242
      
  it "must rotate diagonal paceship to move in positive direction", ->
    r = Cells.analyze Cells.from_rle("$obo$b2o$2o"), single_rot
    assert.deepEqual [r.dx, r.dy], [1,1]

    r1 = Cells.analyze r.cells, single_rot
    assert.deepEqual [r1.dx, r1.dy], [1,1]

  it "must correctly detect patterns in rules with nonstable vacuum", ->

    pattern = Cells.from_rle "$bo$2bo$2bo$bo" #The common )-spaceship

    result = Cells.analyze pattern, critters
    assert.equal result.dx, 2
    assert.equal result.dy, 0
  
    assert.equal result.period, 4
    assert.equal result.cells.length, 4
