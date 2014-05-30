#!/usr/bin/env coffee
fs = require "fs"
{Cells, evaluateCellList, getDualTransform, splitPattern} = require "../scripts-src/cells"
{parse} = require "../scripts-src/rules"
stdio = require "stdio"
{mod, div} = require "../scripts-src/math_util"
{Array2d, MargolusNeighborehoodField} = require "./reversible_ca"

#{SpaceshipCatcher} = require "./application"
#requireemnts:
# - stdio

parseSizePair = (sSize, defVal) ->
  if sSize?
    [swidth, sheight] = sSize.match /(\d+)x(\d+)/
    [parseInt(swidth, 10), parseInt(sheight, 10)]
  else
    defVal

class SpaceshipCatcher
  constructor: (@on_pattern, @max_size=20, @reseed_period=300000) ->
    @search_area=1
    @spaceships_found = []
    @search_radius = 4
    
  #Scan field for the spaceships; remove them from the field
  scan: (gol)->
    f = gol.field
    pick = (x,y) =>
      x0 = gol.snap_below x
      y0 = gol.snap_below y
      fig = f.pick_pattern_at x, y, x0, y0, true, @search_radius, @max_size #pick and erase
      if fig.length <= @max_size
        @on_pattern fig
    for y in [0...@search_area] by 1
      for x in [0...f.width] by 1
        if f.get(x,y) isnt 0 then pick x, y
    for y in [@search_area ... f.height] by 1
      for x in [0...@search_area] by 1
        if f.get(x,y) isnt 0 then pick x, y
    null

onPattern = (rule, maxSteps) -> (pattern) ->
  if result=Cells.analyze(pattern, rule, {max_iters:maxSteps})
    #console.log JSON.stringify result
    if result.period?
      if result.dx isnt 0 or result.dy isnt 0
        #@library.put result, rule
        console.log result.period + "\t" + (Cells.to_rle result.cells)
	
        # console.log "#### Added ss: dx=#{result.
##################
# top-level code #
##################
main = ->
  opts = stdio.getopt {
    'size': {key: 's', args: 1, description: "Size of the field to search, WxH"},
    'seed-size': {key: 'S', args: 1, description: "Size of the area, filled with random initial pattern"},
    'epoch': {key: 'e', args: 1, description: "Epoch length."}
    'seed-percent': {key: 'p', args:1, descrption: "Fill percentageof te seed area"},
    'rule': {key: 'r', args: 1, mandatory:true, description: "Reversible cellular automata rule, required for normalization. Format: 16 comma-separated decimals."}
    }, "output file"
  

  unless opts.args?
    process.stderr.write "Output file not specified\n"
    process.exit 1
    
  console.log opts
  #Now extract the values
  [width, height] = parseSizePair opts.size, [256, 256]
  [seedWidth, seedHeight] = parseSizePair opts['seed-size'], [width>>1, height>>1]
  epochDuration = if opts.epoch? then parseInt(opts.epoch,10) else 10000

  seedPercent = if opts['seed-percent']? then parseInt(opts['seed-percent'], 10)*0.01 else 0.5

  rule = parse opts.rule
  maxSteps = if opts["max-steps"]? then parseInt(opts["max-steps"],10) else 3000
  console.log "Width: #{width},height: #{height}"
  console.log "Seed size: #{seedWidth} x #{seedHeight}"
  console.log "Epoch duration: #{epochDuration}"
  console.log "Seed percent: #{seedPercent}"

  stabRuleset =  rule.stabilize_vacuum()
  console.log "Stable rulest has size #{stabRuleset.length}"

  field = new MargolusNeighborehoodField new Array2d width, height

  epochIndex = 0
  vacuumPeriod = stabRuleset.length
  catcher = new SpaceshipCatcher onPattern(rule, maxSteps), 20
  while true
    console.log "Epoch # #{epochIndex} started"
    epochIndex += 1
    field.clear()
    field.field.random_fill ((width - seedWidth)>>1), ((height - seedHeight)>>1), ((width + seedWidth)>>1), ((height + seedHeight)>>1), seedPercent

    for generation in [0...epochDuration] by vacuumPeriod
      for subRule in stabRuleset
        field.transform subRule
      #pick spaceships
      catcher.scan field
main()

#0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15
#./scripts-src/standalone_searcher.coffee -r 0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15 aaa