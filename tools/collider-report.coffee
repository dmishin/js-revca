#!/usr/bin/env coffee
"use strict"

fs = require "fs"
stdio = require "stdio"
path = require "path"

mustache = require "mustache"
{from_list_elem} = require "../scripts-src/rules"
{Cells} = require "../scripts-src/cells"
{collider} = require "./libcollider"

tfmMatrix2Angle = (tfm) ->
  code = tfm.join " "
  switch code
    when "1 0 0 1" then 0
    when "0 1 -1 0" then 90
    when "-1 0 0 -1" then 180
    when "0 -1 1 0" then 270
    else null
  
main = ()->
  opts = stdio.getopt {}, "report.json output.html"

  ################# Parsing options #######################
  unless opts.args? and opts.args.length in [1..2]
    process.stderr.write "Not enough arguments\n"

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
    rule: rule.stringify()
    collisions:
      for cz, i in data.collisions
        offset1: JSON.stringify cz.offsets[0]
        offset2: JSON.stringify cz.offsets[1]
        timeStart : cz.timeStart
        timeEnd: cz.timeEnd
        index: i + 1
        products:
          for p in cz.products
            name: if (p.info? and p.info.name?) then p.info.name else "?"
            rle:  Cells.to_rle p.pattern
            offset: JSON.stringify p.pos
            angle: tfmMatrix2Angle p.transform
  rendered = mustache.render template, view
  #Rendering data

  fs.writeFileSync outputFile, rendered, {encoding: "utf-8"}

main()
