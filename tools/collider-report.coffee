#!/usr/bin/env coffee
"use strict"

fs = require "fs"
stdio = require "stdio"
path = require "path"

mustache = require "mustache"
{from_list_elem} = require "../scripts-src/rules"
{Cells} = require "../scripts-src/cells"
{mod2} = require "../scripts-src/math_util"
{patternAt} = require "./libcollider"
rle2svg = require "./rle2svg"

tfmMatrix2Angle = (tfm) ->
  code = tfm.join " "
  switch code
    when "1 0 0 1" then 0
    when "0 1 -1 0" then 90
    when "-1 0 0 -1" then 180
    when "0 -1 1 0" then 270
    else null

snap = (x) -> x - mod2(x)
#Take list of pattern-position values and build a collision RLE
collisionPattern = (patternPosList, rule) ->
  tmax = Math.max (pos[2] for [_,pos] in patternPosList)...
  flds = (patternAt(rule, pat, pos, tmax) for [pat, pos] in patternPosList)
  [[].concat(flds ...), tmax]

collisionUrl = (patternPosList, rule) ->
  #http://dmishin.github.io/js-revca/index.html?rule=0,8,4,3,2,5,9,7,1,6,10,11,12,13,14,15&rle_x0=21&rle_y0=25&rle=o$3o$2b2o$4bo$5b2o&step=8&frame_delay=100&size=64x64&cell_size=4,1&phase=0
  base = "http://dmishin.github.io/js-revca/index.html"

  [pattern, time] = collisionPattern patternPosList, rule, time

  p1 = Cells.copy pattern
  Cells.offset p1, mod2(time), mod2(time)
  Cells.normalize p1
  #console.log "#### RLE: #{Cells.to_rle p1}"
  
  [x0, y0, x1, y1] = Cells.bounds pattern

    
  Cells.offset pattern, -snap(x0), -snap(y0)
  Cells.sortXY pattern
  
  width = 64
  height = 64
  step = 1
  frameDelay = 50
  cellSize = 6
  grid = 1
  
  pwidth = x1 - x0
  pheight = y1 - y0

  pcx = snap(((width - pwidth)/2)|0)
  pcy = snap(((height - pheight)/2)|0)

  url = base+"?"+\
        "rule=" + rule.stringify()+\
        "&rle_x0=#{pcx}"+\
        "&rle_y0=#{pcy}"+\
        "&rle=#{Cells.to_rle pattern}"+\
        "&step=#{step}"+\
        "&frame_delay=#{frameDelay}"+\
        "&size=#{width}x#{height}"+\
        "&cell_size=#{cellSize},#{grid}"+\
        "&phase=#{mod2 time}"
  return url

svgStyles = 
  cell: "fill:black;stroke:black"
  bg: "stroke:none;fill:rgb(240,255,255)"
  grid2: "stroke:none;stroke-width:0"
  grid1: "stroke:black;stroke-width:1;stroke-dasharray:1,2"
          
main = ()->
  opts = stdio.getopt {}, "report.json output.html"

  ################# Parsing options #######################
  unless opts.args? and opts.args.length in [1..2]
    process.stderr.write "Not enough arguments\n"
    process.exit 1

  [inFile, outFile] = opts.args
  unless outFile?
    outputFile = inFile.replace(/.json$/, "") + ".html"
  console.log "Writing output to #{outputFile}"
  
  data = JSON.parse fs.readFileSync inFile

  
  rule = from_list_elem data.rule
  [p1, p2] = data.patterns
  
  console.log "#Loaded #{data.collisions.length} collision instances"

  #load template
  templateFile = path.resolve __dirname, "collider-report-template.mustache.html"
  template = fs.readFileSync templateFile, {encoding: "utf-8"}


  view =
    RLE1: Cells.to_rle p1
    RLE2: Cells.to_rle p2
    svg1: rle2svg.pattern2svg(p1, 12, svgStyles).toString pretty:true
    svg2: rle2svg.pattern2svg(p2, 12, svgStyles).toString pretty:true
    rule: rule.stringify()
    collisions:
      for cz, idx in data.collisions
        patternPosList = ([pi, cz.offsets[i]] for pi, i in cz.patterns)
        offset1: JSON.stringify cz.offsets[0]
        offset2: JSON.stringify cz.offsets[1]
        timeStart : cz.timeStart
        timeEnd: cz.timeEnd
        index: idx + 1
        url: collisionUrl patternPosList, rule
        products:
          for p in cz.products.sort((pr1,pr2) -> pr1.pattern.length - pr2.pattern.length)
            name: p.info?.name ? "?"
            rle:  Cells.to_rle p.pattern
            svg:  rle2svg.pattern2svg(p.pattern, 12, svgStyles).toString pretty:true
            offset: JSON.stringify p.pos
            angle: tfmMatrix2Angle p.transform
  rendered = mustache.render template, view
  #Rendering data

  fs.writeFileSync outputFile, rendered, {encoding: "utf-8"}

main()
