#!/usr/bin/env coffee
fs = require "fs"
{Cells, evaluateCellList, getDualTransform, splitPattern} = require "../scripts-src/cells"
rules = require "../scripts-src/rules"
stdio = require "stdio"
{mod2} = require "../scripts-src/math_util"
#requireemnts:
# - stdio


isSelfDual = (rule, record, dualTfm) ->
  offset = [record.result.dx, record.result.dy]

  #canonicalize original pattern orientation, jsut to be sure.
  # usually, library is already canonicalized
  [pattern, dx, dy] = Cells.canonicalize_spaceship record.result.cells, rule, record.result.dx, record.result.dy

  [dual, dx1, dy1] = Cells.getDualSpaceship pattern, rule, dx, dy
  if dx1 isnt dx or dy1 isnt dy
    throw new Error "Dual can't be rotated"

  #now evaluate original until it matches dual, for not more than result.period steps.

  snap_below = (x,generation) ->
      x - mod2(x + generation)
                        
  offsetToOrigin = (pattern, bounds, generation) ->
      [x0,y0] = bounds
      x0 = snap_below x0, generation
      y0 = snap_below y0, generation
      Cells.offset pattern, -x0, -y0
      return [pattern, x0, y0]

  #just make sure that dual is at 0
  [dual] = offsetToOrigin dual, Cells.bounds(dual), 0
  Cells.sortXY dual
  [pattern] = offsetToOrigin pattern, Cells.bounds(pattern), 0
  Cells.sortXY pattern
  
  #console.log "#### Pattern: #{Cells.to_rle(pattern)} Dual: #{Cells.to_rle(dual)}"
  for i in [1 .. record.result.period]
    #phase is always 0.
    pattern1 = evaluateCellList rule.rules[0], pattern, 0
    
    bounds = Cells.bounds pattern1
    [pattern, x0, y0] = offsetToOrigin pattern1, bounds, 1 #here, phase is 1
    Cells.sortXY pattern
    #console.log "####   #{i}\t#{Cells.to_rle(pattern)}"
    if Cells.areEqual pattern, dual
      #console.log "#### self-dual at step #{i} (period = #{record.result.period}): #{Cells.to_rle(pattern)}"
      return true
  #no self-duality found
  return false
    


##################
# top-level code #
##################
main = ->
  opts = stdio.getopt {
    'rule': {key: 'r', args: 1, description: "Reversible cellular automata rule, required for normalization. Format: 16 comma-separated decimals."}
    }, " libary.json"

  unless opts.args?
    process.stderr.write "No input files specified\n"
    process.exit 1

  if opts.rule
    rule = rules.parse opts.rule
  else
    rule = rules.from_list [[0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]]

  [dualTfmName, dualTfm, dualBlockTfm] = getDualTransform rule
  if dualTfmName
    process.stderr.write "Rule has dual transform: #{dualTfmName}\n"
  else
    process.stderr.write "Rule has no dual transform\n"
    process.exit 1

  data = JSON.parse fs.readFileSync opts.args[0]
  process.stderr.write "Read library of #{data.length} items\n"

  nonSelfDualLib = []
  for record in data
    unless isSelfDual rule, record, dualTfm
      nonSelfDualLib.push record

  console.log JSON.stringify nonSelfDualLib
  return
  
main()
