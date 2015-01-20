#!/usr/bin/env coffee
fs = require "fs"
#process = require "process"
cells = require "../scripts-src/cells"



infile = process.argv[2]
unless infile?
  process.stderr.write "Input file not specified\n"
  process.exit 1

data = JSON.parse fs.readFileSync infile

quote = (x) ->
  switch typeof x
    when 'number' then ""+x
    when 'string' then '"' + x.replace('"', '""') + '"'
    else ""+x
  

formatRow = (data) ->
  row = ""
  for v, i in data
    if i > 0
      row += ", "
    row += quote v
  row += "\n"
  row
  
gliderType = (dx, dy) ->
  if dx is 0 and dy is 0
    "static"
  else if dx is 0 or dy is 0
    "orthogonal"
  else if Math.abs(dx)==Math.abs(dy)
    "diagonal"
  else
    "slant"

total = 0
for {result, count, key} in data
  total += count

process.stdout.write formatRow [
    "rle",
    "population",
    "period",
    "dx",
    "dy",
    "speed",
    "type",
    "count",
    "probability"
    ]

for {result, count, key} in data
  process.stdout.write formatRow [
    key,
    result.cells.length,
    result.period,
    result.dx,
    result.dy,
    Math.max(result.dx, result.dy) / result.period,
    gliderType(result.dx, result.dy),
    count,
    count / total
    ]
  