#!/usr/bin/env coffee
fs = require "fs"
{Cells, evaluateCellList, getDualTransform} = require "../scripts-src/cells"
rules = require "../scripts-src/rules"
stdio = require "stdio"
{mod} = require "math_util"
#requireemnts:
# - stdio

##################
# Generic low-level utilities
##################    
shallowCopy = (obj)->
  copied = {}
  for k,v of obj
    copied[k] = v
  return copied

dictionaryValues = (dict)->(v for k,v of dict)

stringifyLibrary = (rle2record) -> JSON.stringify dictionaryValues rle2record

mergeReport = (report_file, key2record) ->
  data = JSON.parse fs.readFileSync report_file
  for record in data
    {result, count, key} = record
    rec = key2record[key]
    if rec?
      rec.count += count
    else
      key2record[key] = record

mergeLibraries = (reports) ->
  key2record = {}
  for report in reports
    mergeReport report, key2record
  return key2record

filterComposites = (rle2record, rule) ->
  filtered = {}
  for rle, rec of rle2record
    {result, count, key} = rec
    grps = cells.splitPattern rule, result.cells, result.period
    if grps.length is 1
      filtered[rle] = rec
  return filtered

makeDualSpaceship = (spaceship, rule, dualTransform, dx, dy) ->
  #Create dual spaceship, which is mirrored and phase-shifted.
  #For the rotational-1 rule, this dual spaceship is also a pattern, that evolutes in reverse direction.

  g1 = Cells.transform (Cells.togglePhase spaceship), dualTransform
  #Transform movement vector too
  [t00, t01, t10, t11] = dualTransform
  dx1 = (t00 * dx + t01 * dy) | 0
  dy1 = (t10 * dx + t11 * dy) | 0
  #And reverse its direction since duality iverses time
  dx1 = -dx1
  dy1 = -dy1
  #Rotate spaceship to the right position
  [g1,dx1, dy1] = Cells.canonicalize_spaceship g1, rule, dx1, dy1
  if (dx1 isnt dx) or (dy1 isnt dy)
    throw new Error "New spaceship moves in the different direction, that's wrong for rotational rule"
  Cells.normalize g1

mergeDualSpaceships = (rle2record, rule, dualTransform) ->
  key2record = {}
  merged = 0
  for rle, record of rle2record
    {result, count, key} = record
    unless result.dx or result.dy
      #skipping non-spaceships
      key2record[rle] = record
      continue
      
    dual = makeDualSpaceship result.cells, rule, dualTransform, result.dx, result.dy
    if key of key2record
      key2record[key].count += count #Duplicate entry?
      process.stderr.write "Duplicate entry: #{key}\n"
    else
      dual_key = Cells.to_rle dual
      if dual_key of key2record
        key2record[dual_key].count += count
        process.stderr.write "   Merging #{rle} to #{dual_key}\n"
        merged += 1
      else
        #Neither dual nor original are not registered yet
        key2record[key] = record
  process.stderr.write "Merged records: #{merged}\n"
  return key2record

findCanonicalForm = (record, rule) ->
  #Find canonical form of a spaceship, according to the minimum of energy
  process.stderr.write "Period is #{record.result.period}\n"
  unless record.result.period?
    #no period -> no way to minimize energy
    return record
    
  snap_below = (x,generation) ->
    x - mod(x + generation, 2)
                        
  offsetToOrigin = (pattern, bounds, generation) ->
    [x0,y0] = Cells.bounds curPattern
    x0 = snap_below x0, generation
    y0 = snap_below y0, generation
    Cells.offset pattern, -x0, -y0
    return [pattern, x0, y0]
    
  energyTreshold = 1e-3
  stable_rules = rules.Rules.stabilize_vacuum rule
  vacuum_period = stable_rules.length
  bestPattern = curPattern = record.result.cells
  bestPatternEnergy = Cells.energy curPattern
  bestPatternRle = record.key
  for i in [0...record.result.period]
    process.stderr.write "   #{i} / #{record.result.period}\n"
    phase = 0
    for stable_rule in stable_rules
      curPattern = evaluateCellList stable_rule, curPattern, phase
      phase ^= 1
    Cells.sortXY curPattern
    
    [curPattern] = offsetToOrigin curPattern, phase
    e = Cells.energy curPattern
    if e > bestPatternEnergy + energyTreshold
      bestPattern = curPattern
      bestPatternEnergy = e
      bestPatternRle = Cells.to_rle curPattern
    else if Math.abs(e - bestPatternEnergy) <= energyTreshold
      curPatternRle = Cells.to_rle curPattern
      if bestPatternRle < curPatternRle
        #resolve case, when energy is the same
        bestPattern = curPattern
        bestPatternEnergy = e
        bestPatternRle = curPatternRle
  newRecord = shallowCopy record
  newRecord.result = shallowCopy newRecord.result
  newRecord.key = bestPatternRle
  newRecord.result.cells = bestPattern
  return newRecord

recalculateCanonicalForm = (rle2record, rule)->
  recalculated = {}
  for rle, record of rle2record
    process.stderr.write "Period is #{record.result.period}\n"
    recordNew = findCanonicalForm record, rule
    if recordNew.key isnt rle
      process.stderr.write "    #{rle} changed to #{recordNew.key}\n"
    if recordNew.key of recalculated
      #Two records gave the same result
      process.stderr.write "Canonical forms matched, merging record #{rle} to #{recordNew.key}\n"
      recalculated[recordNew.key].count += recordNew.count
    else
      recalculated[recordNew.key] = recordNew
  return recalculated

##################
# top-level code #
##################
main = ->
  opts = stdio.getopt {
    'output': {key: 'o', args: 1, description: "Output file. Default is stdout"}
    'allow-composites': {descriptsion: "When specified, composite filtering is not done"}
    'canonicalize': {key: 'c', descriptsion: "Recalculate canonical form of the spaceships"}
#    'alias-file': {key: 'a', args: 1, description: "File of aliases. Format is JSON: {'out-pattern': [in-patterns...]...}"}
    'rule': {key: 'r', args: 1, description: "Reversible cellular automata rule, required for normalization. Format: 16 comma-separated decimals."}
    }, " input1.json input2.json ... "

  console.log JSON.stringify opts

  unless opts.args?
    process.stderr.write "No input files specified\n"
    process.exit 1

  if opts.rule
    rule = rules.Rules.parse opts.rule
  else
    rule = rules.Rules.from_list [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]

  #merge alll given libraries
  rle2record = mergeLibraries opts.args

  process.stderr.write "Read #{opts.args.length} libraries\n"

  unless opts['allow-composites']
    process.stderr.write "Removing composites...\n"
    rle2record = filterComposites rle2record, rule  

  if opts.canonicalize
    process.stderr.write "Re-calculating canonical forms of spaceships in the library\n"
    rle2record = recalculateCanonicalForm rle2record, rule

  if opts.output?
    fs.writeFileSync opts.output, stringifyLibrary(rle2record)
  else
    process.stdout.write stringifyLibrary rle2record


  [dualTfmName, dualTfm, dualBlockTfm] = getDualTransform rule
  if dualTfmName
    process.stderr.write "Rule has dual transform: #{dualTfmName}\n"
    rle2record = mergeDualSpaceships rle2record, rule, dualTfm

main()