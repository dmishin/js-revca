#!/usr/bin/env coffee
"use strict"

{Cells} = require "../scripts-src/cells"
builder = require 'xmlbuilder'

defaultStyles = 
  cell: "fill:blue;stroke:black"
  bg: "stroke:none;fill:rgb(240,255,255)"
  grid1: "stroke:black;stroke-width:1"
  grid2: "stroke:black;stroke-width:1;stroke-dasharray:2,4"

exports.createField = createField = (cells, cols, rows, cell_size, styles = defaultStyles)->
    svg = builder.create "svg", {version: '1.0', encoding: 'UTF-8'}

    rootAttrs =
      xmlns: "http://www.w3.org/2000/svg"
      "xmlns:xlink": "http://www.w3.org/1999/xlink",
      width:  "#{cell_size*cols+1}px",
      height: "#{(cell_size*rows+1)}px"
      viewBox:"0 0 #{cell_size*cols+1} #{cell_size*rows+1}"
    for attr, val of rootAttrs
      svg.att attr, val


    defs = svg.ele("defs")\
      .ele("rect", {
        "id": "cell_image"
        "x":cell_size*0.15
        "y":cell_size*0.15
        "width": cell_size*0.7
        "height": cell_size*0.7
        "style": styles.cell
      })

    background = svg.ele "rect", {
        "x":"0", "y":"0"
        "width":"100%"
        "height":"100%"
        "style": styles.bg
        }
        
    content = svg.ele "g", {"transform":"translate(.5,.5)"}
    grids = content.ele "g", {"id": "grids"}
    grid1 = grids.ele "g", {"style":styles.grid1}
    grid2 = grids.ele "g", {"style":styles.grid2}

    for row in [0..rows]
        grid = [grid1,grid2][row%2]
        sy = "" + (row*cell_size)
        line = grid.ele "line", {
            "x1": "0"
            "y1":sy
            "x2": cols*cell_size
            "y2":sy
        }

    for col in [0..cols]
        grid = [grid1,grid2][col % 2]
        sx = "" + col*cell_size
        line = grid.ele "line", {
            "x1": sx,
            "y1":"0"
            "x2": sx
            "y2":rows*cell_size
        }

    cells_grp = content.ele "g"
    for [x,y] in cells
        xx = x * cell_size
        yy = y * cell_size
        cell = cells_grp.ele "use", {
            "xlink:href": "#cell_image"
            "transform": "translate(#{xx} #{yy})"}
    return svg
    
exports.rle2svg = (rle, size) ->
  cells = Cells.from_rle rle
  [xmin, ymin, xmax, ymax] = Cells.bounds cells
  xmax += 1
  ymax += 1
  xmax += xmax % 2
  ymax += ymax % 2
  createField(cells, xmax, ymax, size).end()

main = (field_size)->
  x0 = 0
  y0 = 0
  rle = "2bo2$b2o$bo"
  size = 8
  cells = Cells.from_rle rle
  Cells.offset cells, x0, y0

  [xmin, ymin, xmax, ymax] = Cells.bounds cells
  xmax += 1
  ymax += 1
  xmax += xmax % 2
  ymax += ymax % 2
    
  options = {}
  if field_size?
    [fs_x, fs_y] = field_size
  else
    fs_x = xmax
    fs_y = ymax

  tree = createField cells, fs_x, fs_y, size
  console.log tree.end {pretty: true}    


#main()
#convert to PNG:
# inkscape -f test.svg -e test.png
