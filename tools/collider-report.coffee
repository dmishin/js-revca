#!/usr/bin/env coffee
"use strict"

fs = require "fs"
stdio = require "stdio"
path = require "path"

mustache = require "mustache"
{from_list_elem} = require "../scripts-src/rules"
{Cells} = require "../scripts-src/cells"


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
  rendered = mustache.render template, view
  #Rendering data

  fs.writeFileSync outputFile, rendered, {encoding: "utf-8"}

main()
