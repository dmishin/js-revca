#Analyses multiple patterns, memoizing intermediate result to speed-up
# processing of duplicates.
#
# Each pattern is an array of [x,y] pairs
{Maximizer, mod, div} = require "./math_util"
{Bits} = require "./rules"
{Cells, evaluateCellList, transformMatrix2BitBlockMap} = require "./cells"
#Creates a string for the pattern.
patternKey = (pattern) -> JSON.stringify pattern  

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

  registerResult: (pattern, result, mainKey) ->
      #Register a pattern with given result, under all keys
      pattern2result = @pattern2result
      pattern2result[mainKey] = result
      for tfm in @symmetries
        transformedKey = patternKey Cells.transform pattern, tfm
        if transformedKey isnt mainKey
          #assert that key either not present, or refers the same result
          #if pattern2result[transformedKey]?
          #  
          pattern2result[transformedKey] = result

  unwrapResult: (result) ->
      console.log "#### Result found:"+JSON.stringify(result)
      #Result may be a real result object, or a reference to another. Dereference, if needed
      if (referenced = result.refersTo)?
        @unwrapResult referenced
      else
        result

  analyse: (pattern) -> #result
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
    vacuum_period = ruleset.length
    pattern = Cells.normalize pattern
                
    #Shift pattern to the origin. Initialfield phase is always 0.
    translateToOrigin pattern, 0
    #sort the pattern to make its key unique
    Cells.sortXY pattern
    key = patternKey pattern
    if (result = @pattern2result[key])?
      return @unwrapResult result
    else
      result = {resolution:null} #result would be calculated later - now only make an empty placeholder
      @registerResult pattern, result, key
                
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
      for stable_rule in ruleset
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
        #Make current result to point to the cached one.
        if knownResult.resolution isnt null
          console.log "#### known result:"+JSON.stringify(knownResult)
          result.refersTo = knownResult
          delete result.resolution
          return @unwrapResult knownResult
      else
        #previously unknown pattern. Register its result (not yet calculated)
        @registerResult curPattern, result, key

      #maybe, analysis has finished?
      if Cells.areEqual pattern, curPattern
        return @makePeriodFoundResult result, dx, dy, iter, bestPatternSearch.getArg()

      #no cycle. Fine.
      bestPatternSearch.put curPattern
      if curPattern.length > maxPopulation
        return @makePatternTooBigResult result
      if Math.max( bounds[2]-bounds[0], bounds[3]-bounds[1]) > maxSize
        return @makePatternToWideResult result

    #After the given number of iterations, nothing was found.
    #Give up.
    @makeCycleNotFoundResult result

  makePeriodFoundResult: (result, dx, dy, period, bestPattern)->
    #console.log "#### period found"
    [bestPattern, result.dx, result.dy] =
         Cells.canonicalize_spaceship bestPattern, @rule, dx, dy
    result.period = period
    result.cells = bestPattern
    return result

  makePatternToWideResult: (result)->
    #console.log "#### pattern too wide"
    result.resolution = "pattern too large"
    result

  makePatternTooBigResult: (result)->   
    #console.log "#### pattern too big"
    result.resolution = "pattern too populated"
    result
  makeCycleNotFoundResult: (result)->
    #console.log "#### nop cycle found"
    result.resolution = "cycle not found"
    result