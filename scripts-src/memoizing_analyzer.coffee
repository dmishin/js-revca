#Analyses multiple patterns, memoizing intermediate result to speed-up
# processing of duplicates.
#
# Each pattern is an array of [x,y] pairs
{Maximizer, mod, div} = require "./math_util"
{Bits} = require "./rules"
{Cells, evaluateCellList, transformMatrix2BitBlockMap} = require "./cells"
#Creates a string for the pattern.
patternKey = (pattern) -> JSON.stringify pattern  

exports.Resolution = Resolution = Object.freeze
  HAS_PERIOD: "period found"
  NO_PERIOD :   "no period found"
  OVERPOPUPATION: "population too large"
  TOO_WIDE: "size to large"
  

ruleSpatialSymmetries = (rule)-> #list of matrices, except identity matrix
  #dumb algorithm: just check every transform. Who cares - it is called once.
  symmetries = []
  first = true
  for s1 in [1 .. -1] by -2
    for s2 in [1 .. -1] by -2
      for tfm in  [[s1,0,0,s2], [0,s1,s2,0]]
        if first
          first = false
        else
          blockTfm = transformMatrix2BitBlockMap tfm
          if rule.is_transposable_with ((x) -> blockTfm[x])
            symmetries.push tfm
  return symmetries
  
exports.MemoAnalyser = class MemoAnalyser
  constructor: (@rule)->
    @ruleset = rule.stabilize_vacuum()
    #Memoizing table to speed up alaysis. Pattern 
    @pattern2result = {}
    @maxIters = 3000
    @maxPopulation = 1024
    @maxSize = 100
    @symmetries = ruleSpatialSymmetries rule
    @frozen = false
    @doubleHitCount = 0
    @currentPatternKeys = []

  freeze: ->
    @frozen = true
    @truncateTable

  stashKeys: (pattern, mainKey) ->
    keys = @currentPatternKeys
    keys.push mainKey
    for tfm in @symmetries
      transformedKey = patternKey Cells.transform pattern, tfm
      keys.push transformedKey
    return
    
  writeResult: (result) ->
    pattern2result = @pattern2result
    for key in @currentPatternKeys
      pattern2result[key] = result
    @currentPatternKeys = []
    return

  analyse: (pattern) ->
    result = @_analyse pattern
    result.hits += 1
    if result.hits is 2
      @doubleHitCount += 1
    return result

  _analyse: (pattern) -> #result
    #Perform analysys of the pattern. 
    #Pattern must correspond to the initial phase of the ruleset

    maxIters = @maxIters
    maxPopulation = @maxPopulation

    maxSize = @maxSize

    #field phase is 0 or 1; 
    #returns maximal value y, such that (y mod 2 === fieldPhase) && y <= x
    snap_below = (x, fieldPhase) ->
      x - mod(x + fieldPhase, 2)

    #modifies the pattern inplace. Returns coordinates of the pattern's origin
    translateToOrigin = (pattern, fieldPhase) ->
      [x0,y0] = Cells.topLeft pattern
      x0 = snap_below x0, fieldPhase
      y0 = snap_below y0, fieldPhase
      Cells.offset pattern, -x0, -y0
      return [x0, y0]

    ruleset = @ruleset
    vacuum_period = ruleset.size()
    pattern = Cells.normalize pattern
                
    #Shift pattern to the origin. Initialfield phase is always 0.
    translateToOrigin pattern, 0
    #sort the pattern to make its key unique
    Cells.sortXY pattern
    key = patternKey pattern
    if (result = @pattern2result[key])?
      #console.log "#### FIrst hit!"
      return result
    else
      @stashKeys pattern, key
                
    bestPatternSearch = new Maximizer Cells.energy
    bestPatternSearch.put pattern
    
    #start search
    hasCycle = false
    curPattern = pattern
    dx = 0
    dy = 0
    for iter in [vacuum_period .. maxIters] by vacuum_period
      #evaluate cell list, always assuming initial, 0 phase
      phase = 0
      for stable_rule in ruleset.rules
        curPattern = evaluateCellList stable_rule, curPattern, phase
        phase ^= 1
        
      #console.log "#### Iter #{ iter }\t:  #{ @to_rle @normalizeXY curPattern[..] }"
      #After evaluation, pattern's phase might be not 0. 
      #Remove offset and transform back to phase 0

      bounds = Cells.bounds curPattern
      [x0, y0] = translateToOrigin curPattern, phase
      dx += x0
      dy += y0

      #Now pattern's phase is 0 again. Restore unique order of cells:
      Cells.sortXY curPattern

      #check whether we already had it:
      key = patternKey curPattern
      #Maybe, we already had this value?
      if (knownResult = @pattern2result[key])?
        #Write current result to the stashed keys
        #console.log "#### known result:"+JSON.stringify(knownResult)
        result = knownResult
        break

      #maybe, analysis has finished?
      if Cells.areEqual pattern, curPattern
        result = @makePeriodFoundResult dx, dy, iter, bestPatternSearch.getArg()
        break
        
      #previously unknown pattern. Remember its keys
      @stashKeys curPattern, key

      #no cycle. Fine.
      bestPatternSearch.put curPattern
      if curPattern.length > maxPopulation
        result = @makePatternTooBigResult()
        break
      if Math.max( bounds[2]-bounds[0], bounds[3]-bounds[1]) > maxSize
        result = @makePatternToWideResult()
        break

    unless result?
      #After the given number of iterations, nothing was found.
      #Give up.
      result = @makeCycleNotFoundResult()

    @writeResult result
    return result


  makePeriodFoundResult: (dx, dy, period, bestPattern)->
    #console.log "#### period found"
    [bestPattern, dx0, dy0] =
         Cells.canonicalize_spaceship bestPattern, @rule, dx, dy
    return {
      resolution: Resolution.HAS_PERIOD
      dx: dx0
      dy: dy0
      period: period
      cells: bestPattern
      hits: 0
    }
    
  makePatternToWideResult: ->
    #console.log "#### pattern too wide"
    return {
      resolution: Resolution.TOO_WIDE
      hits: 0
    }
  makePatternTooBigResult: ->   
    #console.log "#### pattern too big"
    return {
      resolution: Resolution.OVERPOPUPATION
      hits: 0
    }
  makeCycleNotFoundResult: ->
    #console.log "#### no cycle found"
    return {
      resolution: Resolution.NO_PERIOD
      hits: 0
    }

  #Truncate memo table to the given number of records, removing items with the least hit count
  truncateTable: (maxRecords) ->
    if maxRecords < 0
      throw new Error "Number of records must be positive"
    pattern2result = @pattern2result
    keysWithHits = ([result.hits, key] for key, result of pattern2result)
    #sort keys by hit count, more hits go first
    keysWithHits.sort (kh1, kh2) -> kh2[0]-kh1[0]
    #remove the rest keys
    for i in [maxRecords ... keysWithHits.length] by 1
      key = keysWithHits[i][1]
      delete pattern2result[key]
    return
