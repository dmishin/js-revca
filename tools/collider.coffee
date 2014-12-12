#!/usr/bin/env coffee
"use strict"
# Particle collider.
# Make collision table

fs = require "fs"
{Cells, inverseTfm, evaluateCellList, getDualTransform, splitPattern} = require "../scripts-src/cells"
{from_list_elem, parseElementary} = require "../scripts-src/rules"
stdio = require "stdio"
{mod,mod2} = require "../scripts-src/math_util"
{patternAt} = require "./libcollider"

#GIven 2 3-vectors, return 3-ort, that forms full basis with both vectors
opposingOrt = (v1, v2) ->
  for i in [0..2]
    ort = [0,0,0]
    ort[i] = 1
    if isCompleteBasis v1, v2, ort
      return [i, ort]
  throw new Error "Two vectors are collinear"  

#Scalar product of 2 vectors
dot = (a,b) ->
  s = 0
  for ai, i in a
    s += ai*b[i]
  return s
  
#project 3-vector vec to the null-space of ort
#projectToNullSpace = (ort, vec) ->
#  if dot(ort,ort) isnt 1
#    throw new Error "Not an ort!"
#  p = dot ort, vec
#  
#  return (vec[i] - ort[i]*p for i in [0...3] )

#Remove component from a vector
removeComponent =( vec, index) ->
  result = []
  for xi, i in vec
    if i isnt index
      result.push xi
  return result

restoreComponent = (vec, index) ->
  #insert 0 into index i
  v = vec[..]
  v.splice index, 0, 0
  return v  

isCompleteBasis = (v1, v2, v3) ->
  #determinant of a matrix of 3 vectors. copipe from maxima
  det = v1[0]*(v2[1]*v3[2]-v3[1]*v2[2])-v1[1]*(v2[0]*v3[2]-v3[0]*v2[2])+(v2[0]*v3[1]-v3[0]*v2[1])*v1[2]
  return det isnt 0

#Area of a tetragon, built on 2 vectors. May be negative.
area2d = ([x1,y1],[x2,y2]) ->  x1*y2 - x2*y1

vecSum = (v1, v2) ->   (v1i+v2[i] for v1i, i in v1)
vecDiff = (v1, v2) ->  (v1i-v2[i] for v1i, i in v1)
vecScale = (v1, k) ->  (v1i*k for v1i in v1)

#Returns list of coordinates of points in elementary cell
# both vectors must be 2d, nonzero, non-collinear
elementaryCell2d = (v1, v2) ->
  #vertices
  [x1,y1] = v1
  [x2,y2] = v2
  if area2d(v1,v2) is 0
    throw new Error "vectors are collinear!"
  #orient vectors
  if x1 < 0
    x1 = -x1
    y1 = -y1
  if x2 < 0
    x2 = -x2
    y2 = -y2
  # x intervals:
  # 0, min(x1,x2), max(x1,x2), x1+x2
  xs = [0, x1, x2, x1+x2]
  xmin = Math.min xs ...
  xmax = Math.max xs ...
  
  ys = [0, y1, y2, y1+y2]
  ymin = Math.min ys ...
  ymax = Math.max ys ...

  d = x2*y1-x1*y2 #determinant of the equation
  s = if d < 0 then -1 else 1
  points = []
  for x in [xmin .. xmax] by 1
    for y in [ymin .. ymax] by 1
      #check that the point belongs to the rhombus
      #[t1 = (x2*y-x*y2)/d,
      # t2 = -(x1*y-x*y1)/d]
      #condition is: t1,2 in [0, 1)
      if ( 0 <= (x2*y-x*y2)*s < d*s ) and ( 0 <= -(x1*y-x*y1)*s < d*s )
        points.push [x,y]
  return points

#Calculate parameters of the collision:
# collision time, nearest node points, collision distance.
#  pos : position [x, y, t]
#  delta : velocity and period [dx, dy, dt]
collisionParameters = (pos0, delta0, pos1, delta1) ->
  #pos and delta are 3-vectors: (x,y,t)
  #
  #deltax : dx+a*vx0-b*vx1;
  #deltay : dy+a*vy0-b*vy1;
  #deltat : dt+a*p0-b*p1;
  # Dropbox.Math.spaceship-collision
  [dx, dy, dt] = vecDiff pos0, pos1
  [vx0, vy0, p0] = delta0
  [vx1, vy1, p1] = delta1
  
  #  D = p0**2*vy1**2-2*p0*p1*vy0*vy1+p1**2*vy0**2 + p0**2*vx1**2-2*p0*p1*vx0*vx1+p1**2*vx0**2
  D = (p0*vy1 - p1*vy0)**2 + (p0*vx1-p1*vx0)**2
      
  a = -(dt*p0*vy1**2+(-dt*p1*vy0-dy*p0*p1)*vy1+dy*p1**2*vy0+dt*p0*vx1**2+(-dt*p1*vx0-dx*p0*p1)*vx1+dx*p1**2*vx0) / D
  
  b =  -((dt*p0*vy0-dy*p0**2)*vy1-dt*p1*vy0**2+dy*p0*p1*vy0+(dt*p0*vx0-dx*p0**2)*vx1-dt*p1*vx0**2+dx*p0*p1*vx0) / D

  dist = Math.abs(dt*vx0*vy1-dx*p0*vy1-dt*vx1*vy0+dx*p1*vy0+dy*p0*vx1-dy*p1*vx0)/Math.sqrt(D)

  #nearest points with time before collision time
  ia = Math.floor(a)|0
  ib = Math.floor(b)|0
  npos0 = vecSum pos0, vecScale(delta0, ia)
  npos1 = vecSum pos1, vecScale(delta1, ib)
  tcoll =  pos0[2] + delta0[2]*a
  tcoll1 =  pos1[2] + delta1[2]*b #must be same as tcoll1
  if Math.abs(tcoll-tcoll1) > 1e-6 then throw new Error "assert: tcoll"
    
  return {
    dist: dist    #distance of the nearest approach
    npos0: npos0
    npos1: npos1  #node point nearest to the collision (below)
    tcoll: tcoll  #when nearest approach occurs
  }

#In what rande DX can change, if minimal distanec between 2 patterns is less than dmax?
# This fucntion gives the answer.
# Calculation is in the maxima sheet:
# solve( d2 = dd^2, dx );
dxRange = (dPos, v0, v1, dMax) ->
  #dPos, v0, v1 :: vector3
  #dMax :: integer
  [_, dy, dt] = dPos #dx is ignored, because we will find its diapason
  [vx0, vy0, p0] = v0
  [vx1, vy1, p1] = v1

  #Solution from Maxima:
  # dx=-(dd*sqrt(p0^2*vy1^2-2*p0*p1*vy0*vy1+p1^2*vy0^2+p0^2*vx1^2-2*p0*p1*vx0*vx1+p1^2*vx0^2)-dt*vx0*vy1+dt*vx1*vy0-dy*p0*vx1+dy*p1*vx0)/(p0*vy1-p1*vy0)
  # q = p0^2*vy1^2-2*p0*p1*vy0*vy1+p1^2*vy0^2+p0^2*vx1^2-2*p0*p1*vx0*vx1+p1^2*vx0^2
  # 
  # dx=(+-dd*sqrt(q)-dt*vx0*vy1+dt*vx1*vy0-dy*p0*vx1+dy*p1*vx0)/(p1*vy0 - p0*vy1)
  num = p1*vy0 - p0*vy1
  if num is 0
    #throw new Error "Patterns are parallel and neveer touch"
    return [0, -1]
    
  dc = (-dt*vx0*vy1+dt*vx1*vy0-dy*p0*vx1+dy*p1*vx0) / num
  #q = p0^2*vy1^2-2*p0*p1*vy0*vy1+p1^2*vy0^2  +  p0^2*vx1^2-2*p0*p1*vx0*vx1+p1^2*vx0^2
  q = (p0*vy1-p1*vy0)**2 + (p0*vx1-p1*vx0)**2 #after small simplification

  delta = Math.abs(Math.sqrt(q) * (dMax / num))

  #return upper and lower limits, rounded to integers
  return [Math.floor(dc - delta)|0, Math.ceil(dc + delta)|0]

#Same as dxRange, but for dy. Reuses dxRange
dyRange = (dPos, v0, v1, dMax) ->
  swapxy = ([x,y,t]) -> [y,x,t]
  dxRange swapxy(dPos), swapxy(v0), swapxy(v1), dMax

#Chooses one of dxRange, dyRange.
freeIndexRange = (dPos, v0, v1, dMax, index) ->
  if index not in [0..1] then throw new Error "Unsupported index #{index}"
  [dxRange, dyRange][index](dPos, v0, v1, dMax)

#Calculate time, when 2 spaceship approach to the specified distance.
approachParameters = (pos0, delta0, pos1, delta1, approachDistance) ->
  [dx, dy, dt] = vecDiff pos0, pos1
  [vx0, vy0, p0] = delta0
  [vx1, vy1, p1] = delta1


  #solve( [deltax^2 + deltay^2 = dd^2, deltat=0], [a,b] );
  dd = approachDistance
  D = (p0**2*vy1**2-2*p0*p1*vy0*vy1+p1**2*vy0**2+p0**2*vx1**2-2*p0*p1*vx0*vx1+p1**2*vx0**2)
  #thanks maxima. The formula is not well optimized, but I don't care.
  Q2 = (-dt**2*vx0**2+2*dt*dx*p0*vx0+(dd**2-dx**2)*p0**2)*vy1**2+(((2*dt**2*vx0-2*dt*dx*p0)*vx1-2*dt*dx*p1*vx0+(2*dx**2-2*dd**2)*p0*p1)*vy0+(2*dx*dy*p0**2-2*dt*dy*p0*vx0)*vx1+2*dt*dy*p1*vx0**2-2*dx*dy*p0*p1*vx0)*vy1+(-dt**2*vx1**2+2*dt*dx*p1*vx1+(dd**2-dx**2)*p1**2)*vy0**2+(2*dt*dy*p0*vx1**2+(-2*dt*dy*p1*vx0-2*dx*dy*p0*p1)*vx1+2*dx*dy*p1**2*vx0)*vy0+(dd**2-dy**2)*p0**2*vx1**2+(2*dy**2-2*dd**2)*p0*p1*vx0*vx1+(dd**2-dy**2)*p1**2*vx0**2

  if Q2 < 0
    #Approach not possible, spaceships are not coming close enough
    return {approach: false}
    
  Q = Math.sqrt(Q2)
  
  a = -(p1*Q+dt*p0*vy1**2+(-dt*p1*vy0-dy*p0*p1)*vy1+dy*p1**2*vy0+dt*p0*vx1**2+(-dt*p1*vx0-dx*p0*p1)*vx1+dx*p1**2*vx0) / D
 
  b = -(p0*Q+(dt*p0*vy0-dy*p0**2)*vy1-dt*p1*vy0**2+dy*p0*p1*vy0+(dt*p0*vx0-dx*p0**2)*vx1-dt*p1*vx0**2+dx*p0*p1*vx0) / D

  tapp = pos0[2]+p0*a
  tapp1 = pos1[2]+p1*b
  if Math.abs(tapp1-tapp) >1e-6 then throw new Error "Assertion failed"
  ia = Math.floor(a)|0
  ib = Math.floor(b)|0
  npos0 = vecSum pos0, vecScale(delta0, ia)
  npos1 = vecSum pos1, vecScale(delta1, ib)
  return {
    approach: true
    npos0 : npos0 #nearest positions before approach
    npos1 : npos1
    tapp : tapp
  }

#Give n position: [x,y,t] and delta: [dx,dy,dt],
# Return position with biggest time <= t (inclusive).
firstPositionBefore = (pos, delta, time) ->
  # find integer i:
  # t + i*dt < time
  #
  # i*dt < time - t
  # i < (time-t)/dt
  i0 = (time - pos[2]) / delta[2] #not integer.
  #now find the nearest integer below
  i = (Math.floor i0) |0
  #and return the position
  vecSum pos, vecScale delta, i

#Given spaceship trajectory, returns first it position before the given moment of time (inclusive)    
firstPositionAfter = (pos, delta, time) ->
  i0 = (time - pos[2]) / delta[2] #not integer.
  i = (Math.ceil i0) |0
  vecSum pos, vecScale delta, i

    
#Normalize pattern and returns its rle.
normalizedRle = (fld, time=0) ->
  ff = Cells.copy fld
  phase = mod2 time
  Cells.offset ff, phase, phase
  Cells.normalize ff
  Cells.to_rle ff


  
# Collide 2 patterns: p1 and p2,
#    p1 at [0,0,0] and p2 at `offset`.
#    initialSeparation::int approximate initial distance to put patterns at. Should be large enought for patterns not to intersect
#    offset: [dx, dy, dt] - initial offset of the pattern p2 (p1 at 000)
#    collisionTreshold:: if patterns don't come closer than this distance, don't consider them colliding.
#    waitForCollision::int How many generations to wait after the approximate nearest approach, until the interaction would start.
#
#  Returned value: object
#    collision::bool true if collision
#    patterns :: [p1, p2] two patterns
#    offsets  :: [vec1, vec2] first position of each pattern before collision time
#    timeStart::int first generation, where interaction has started
#    products::[ ProductDesc ]  list of collision products (patterns with their positions and classification
doCollision = (rule, library, p1, v1, p2, v2, offset, initialSeparation = 30, collisionTreshold=20)->
  waitForCollision = v1[2] + v2[2] #sum of periods
  params = collisionParameters [0,0,0], v1, offset, v2  
  ap = approachParameters [0,0,0], v1, offset, v2, initialSeparation
  collision = {collision:false}
  if not ap.approach
    #console.log "#### No approach, nearest approach: #{params.dist}"
    return collision
  if params.dist > collisionTreshold
    #console.log "#### Too far, nearest approach #{params.dist} > #{collisionTreshold}"
    return collision
  
  #console.log "#### CP: #{JSON.stringify params}"
  #console.log "#### AP: #{JSON.stringify ap}"
  
  #Create the initial field. Put 2 patterns: p1 and p2 at initial time 
  #nwo promote them to the same time, using list evaluation
  time = Math.max ap.npos0[2], ap.npos1[2]
  fld1 = patternAt rule, p1, ap.npos0, time
  fld2 = patternAt rule, p2, ap.npos1, time
  
  #OK, collision prepared. Now simulate both spaceships separately and
  # together, waiting while interaction occurs
  timeGiveUp = params.tcoll + waitForCollision #when to stop waiting for some interaction
  coll = simulateUntilCollision rule, [fld1, fld2], time, timeGiveUp
  fld1 = fld2 = null #They are not needed anymore
  
  if not coll.collided
    #console.log "#### No interaction detected until T=#{timeGiveUp}. Give up."
    return collision
    
  #console.log "#### colliding:"
  #console.log "#### 1)  #{normalizedRle p1} at [0, 0, 0]"
  #console.log "#### 2)  #{normalizedRle p2} at #{JSON.stringify offset}"
  #console.log "####     collision at T=#{coll.time}  (give up at #{timeGiveUp})"
  collision.timeStart = coll.time
  collision.patterns = [p1, p2]
  collision.offsets = [
    firstPositionBefore([0,0,0], v1, coll.time-1),
    firstPositionBefore(offset,  v2, coll.time-1),
  ]  
  collision.collision = true
  
  
  {products, verifyTime, verifyField} = finishCollision rule, library, coll.field, coll.time
  collision.products = products
  #findEmergeTime = (rule, products, minimalTime) ->
  collision.timeEnd = findEmergeTime rule, collision.products, collision.timeStart, verifyField, verifyTime
  #Update positions of products
  for product in collision.products
    product.pos = firstPositionAfter product.pos, product.delta, collision.timeEnd+1

  #normalize relative to the first spaceship
  translateCollision collision, vecScale(collision.offsets[0], -1)
  #return collision

#Offser collision information record by the given amount, in time and space
translateCollision = (collision, dpos) ->
  [dx, dy, dt] = dpos
  for o, i in collision.offsets
    collision.offsets[i] = vecSum o, dpos
  collision.timeStart += dt
  collision.timeEnd += dt
  for product in collision.products
    product.pos = vecSum product.pos, dpos
  return collision

#Simulate several patterns until they collide.
# Return first oment of time, when patterns started interacting.
simulateUntilCollision = (rule, patterns, time, timeGiveUp) ->
  if patterns.length < 2 then return {collided: false} # 1 pattern can't collide.
  fld  = [].concat patterns ... #concatenate all patterns
  while time < timeGiveUp
    phase = mod2 time
    #evaluate each pattern separately
    #console.log "### patterns: #{JSON.stringify patterns}"
    patterns = (evaluateCellList(rule, p, phase) for p in patterns)
    #console.log "### after eval: #{JSON.stringify patterns}"
    #And together
    fld  = evaluateCellList rule, fld,  phase
    time += 1
    #check if they are different
    mergedPatterns = [].concat patterns...
    Cells.sortXY fld
    Cells.sortXY mergedPatterns
    if not Cells.areEqual fld, mergedPatterns
      #console.log "#### Collision detected! T=#{time}, #{normalizedRle fld}"
      #console.log "#### collision RLE: #{normalizedRle fld, time}"
      return {
        collided: true
        time: time
        field: fld
      }
  return{
    collided: false
  }

### Given the rule and the list of collition products (with their positions)
#   find a moment of time when they emerged.
# verifyField, verifyTime: knwon state of the field, for verification.
###
findEmergeTime = (rule, products, minimalTime, verifyField, verifyTime) ->
  invRule = rule.reverse()
  #Time position of the latest fragment
  maxTime = Math.max (p.pos[2] for p in products)...
  if verifyTime? and maxTime < verifyTime
    throw new Error "Something is strange: maximal time of fragments smaller than verification time"
  #Prepare all fragments, at time maxTime
  patterns = for product in products
    #console.log "#### Product: #{JSON.stringify product}"
    #first, calculate first space-time point before the maxTime
    initialPos = firstPositionBefore product.pos, product.delta, maxTime
    #Put the pattern at this point
    pattern = Cells.transform product.pattern, product.transform, false
    patternAt rule, pattern, initialPos, maxTime

  if verifyTime?
    allPatterns = [].concat(patterns...)
    patternEvolution invRule, allPatterns, 1-maxTime, (p, t)->
      if t is (1 - verifyTime)
        #console.log "#### verifying. At time #{1-t} "
        #console.log "####    Expected: #{normalizedRle verifyField}"
        #console.log "####    Got     : #{normalizedRle p}"
        Cells.sortXY p
        Cells.sortXY verifyField
        if not Cells.areEqual verifyField, p
          throw new Error "Verification failed: reconstructed backward collision did not match expected"
        return false
      else
        return true

  #console.log "#### Generated #{patterns.length} patterns at time #{maxTime}:"
  #console.log "#### #{normalizedRle [].concat(patterns...)}"
  
  #Now simulate it inverse in time
  invCollision = simulateUntilCollision invRule, patterns, -maxTime+1, -minimalTime
  if not invCollision.collided
    throw new Error "Something is wrong: patterns did not collided in inverse time"
  return 1-invCollision.time    
  
#simulate patern until it decomposes into several simple patterns
# Return list of collision products
finishCollision = (rule, library, field, time) ->
  #console.log "#### Collision RLE: #{normalizedRle field}"
  growthLimit = field.length*3 + 8  #when to try to separate pattern

  while true
    field = evaluateCellList rule, field, mod2(time)
    time += 1
    [x0, y0, x1,y1] = Cells.bounds field
    size = Math.max (x1-x0), (y1-y0)
    #console.log "####    T:#{time}, s:#{size}, R:#{normalizedRle field}"
    if size > growthLimit
      #console.log "#### At time #{time}, pattern grew to #{size}: #{normalizedRle field}"
      verifyTime = time
      verifyField = field
      break
  #now try to split result into several patterns
  parts = separatePatternParts field
  #console.log "#### Detected #{parts.length} parts"
  if parts.length is 1
    #TODO: increase growth limit?
    #console.log "#### only one part, try more time"
    return finishCollision rule, library, field, time
    
  results = []
  for part, i in parts
    #now analyze this part
    res = analyzeFragment rule, library, part, time
    for r in res
      results.push r
      
  return{
    products: results
    verifyTime: verifyTime
    verifyField: field
  }

analyzeFragment = (rule, library, pattern, time, options={})->
  analysys = determinePeriod rule, pattern, time, options
  if analysys.cycle
    #console.log "####      Pattern analysys: #{JSON.stringify analysys}"
    res = library.classifyPattern pattern, time, analysys.delta...
    [res]
  else
    console.log "####      Pattern not decomposed completely: #{normalizedRle pattern} #{time}"
    finishCollision(rule, library, pattern, time).products
      
#detect periodicity in pattern
# Returns :
#   cycle::bool - is cycle found
#   error::str - if not cycle, says error details. Otherwise - udefined.
#   delta::[dx, dy, dt] - velocity and period, if cycle is found.
determinePeriod = (rule, pattern, time, options={})->
    pattern = Cells.copy pattern
    Cells.sortXY pattern
    max_iters = options.max_iters ? 2048
    max_population = options.max_population ? 1024
    max_size = options.max_size ? 1024
        
    #wait for the cycle  
    result = {cycle: false}
    patternEvolution rule, pattern, time, (curPattern, t) ->
      dt = t-time
      if dt is 0 then return true
      Cells.sortXY curPattern
      eq = Cells.shiftEqual pattern, curPattern, mod2 dt
      if eq
        result.cycle = true
        eq.push dt
        result.delta = eq
        return false
      if curPattern.length > max_population
        result.error = "pattern grew too big"
        return false
      bounds = Cells.bounds curPattern
      if Math.max( bounds[2]-bounds[0], bounds[3]-bounds[1]) > max_size
        result.error = "pattern dimensions grew too big"
        return false
      return true #continue evaluation
    return result

snap_below = (x,generation) ->
  x - mod2(x + generation)

#move pattern to 0,                                             
offsetToOrigin = (pattern, generation) ->
  [x0,y0] = Cells.topLeft pattern
  x0 = snap_below x0, generation
  y0 = snap_below y0, generation
  Cells.offset pattern, -x0, -y0
  return [x0, y0]

#Continuousely evaluate the pattern
# Only returns pattern in ruleset phase 0.
patternEvolution = (rule, pattern, time, callback)->
  #pattern = Cells.copy pattern
  stable_rules = [rule]
  vacuum_period = stable_rules.length #ruleset size
  curPattern = pattern
  while true
    phase = mod2 time
    sub_rule_idx = mod time, vacuum_period
    if sub_rule_idx is 0
      break unless callback curPattern, time
    curPattern = evaluateCellList stable_rules[sub_rule_idx], curPattern, phase
    time += 1
  return


class Library
  constructor: (@rule) ->
    @rle2pattern = {}
     
  #Assumes that pattern is in its canonical form
  addPattern: (pattern, data) ->
    rle = Cells.to_rle pattern
    if @rle2pattern.hasOwnProperty rle
      throw new Error "Pattern already present: #{rle}"
    @rle2pattern[rle] = data
    
  addRle: (rle, data) ->
    pattern = Cells.from_rle rle
    analysys = determinePeriod @rule, pattern, 0
    if not analysys.cycle then throw new Error "Pattern #{rle} is not periodic!"
    #console.log "#### add anal: #{JSON.stringify analysys}"
    [dx,dy,p]=delta=analysys.delta
    unless (dx>0 and dy>=0) or (dx is 0 and dy is 0)
      throw new Error "Pattern #{rle} moves in wrong direction: #{dx},#{dy}"
    @addPattern pattern, data ? {delta: delta}
      
  classifyPattern: (pattern, time, dx, dy, period) ->
    #determine canonical ofrm ofthe pattern, present in the library;
    # return its offset
    
    #first: rotate the pattern caninically, if it is moving
    if dx isnt 0 or dy isnt 0
      [dx1, dy1, tfm] = Cells._find_normalizing_rotation dx, dy
      pattern1 = Cells.transform pattern, tfm, false #no need to normalize
      result = @_classifyNormalizedPattern pattern1, time, dx1, dy1, period
      result.transform = inverseTfm tfm
    else
      #it is not a spaceship - no way to find a normal rotation. Check all 4 rotations.
      for tfm in Cells._rotations
        pattern1 = Cells.transform pattern, tfm, false
        result = @_classifyNormalizedPattern pattern1, time, 0, 0, period
        result.transform = inverseTfm tfm
        if result.found
          break
          
    #reverse-transform position
    [x,y,t] = result.pos
    #console.log "#### Original pos: #{JSON.stringify result.pos}"
    [x,y] = Cells.transformVector [x,y], result.transform #no normalize!
    #console.log "#### after inverse rotate: #{JSON.stringify [x,y,t]}"
    result.pos = [x,y,t]
    result.delta = [dx,dy,period]
    return result

  _classifyNormalizedPattern: (pattern, time, dx, dy, period) ->
    #console.log "#### Classifying: #{JSON.stringify pattern} at #{time}"
    result = {found:false}
    self = this
    patternEvolution @rule, pattern, time, (p, t)->
      p = Cells.copy p
      [dx, dy] = offsetToOrigin p, t
      Cells.sortXY p
      rle = Cells.to_rle p
      #console.log "####    T:#{t}, rle:#{rle}"
      if rle of self.rle2pattern 
        #console.log "####      found! #{rle}"
        result.pos = [dx, dy, t]
        result.rle = rle
        result.pattern = p
        result.found=true
        result.info = self.rle2pattern[rle]
        return false
      return (t-time) < period
      
    if not result.found
      p = Cells.copy pattern
      [dx, dy] = offsetToOrigin p, time
      Cells.sortXY p
      result.pos = [dx, dy, time]
      result.rle = Cells.to_rle p
      result.pattern = p
      result.found = false
      result.transform = [1,0,0,1]
    return result
    
  #load library from the simple JSON file.
  # Library format is simplified: "rle": data, where data is arbitrary object
  load: (file) ->
    fs = require "fs"
    libData = JSON.parse fs.readFileSync file, "utf8"
    #re-parse library data to ensure its correctness
    n = 0
    for rle, data of libData
      @addPattern Cells.from_rle(rle), data
      n += 1
    console.log "#### Loaded #{n} patterns from library #{file}"
    return
  
# geometrically separate pattern into several disconnected parts
# returns: list of sub-patterns
separatePatternParts = (pattern, range=4) ->
  
  mpattern = {} #set of visited coordinates
  key = (x,y) -> ""+x+"#"+y
  has_cell = (x,y) -> mpattern.hasOwnProperty key x, y
  erase = (x,y) -> delete mpattern[ key x, y ]

  #convert pattern to map-based repersentation
  for xy in pattern
    mpattern[key xy...] = xy

  cells = []

  #return true, if max size reached.
  do_pick_at = (x,y)->
    erase x, y
    cells.push [x,y]
    for dy in [-range..range] by 1
      y1 = y+dy
      for dx in [-range..range] by 1
        continue if dy is 0 and dx is 0
        x1 = x+dx
        if has_cell x1, y1
          do_pick_at x1, y1
    return

  parts = []
  while true
    hadPattern = false
    for _k, xy of mpattern
      hadPattern = true #found at least one non-picked cell
      do_pick_at xy ...
      break
    if hadPattern
      parts.push cells
      cells = []
    else
      break
  return parts
    
#in margolus neighborhood, not all offsets produce the same pattern
isValidOffset = ([dx, dy, dt]) -> ((dx+dt)%2 is 0) and ((dy+dt)%2 is 0)
############################

#Mostly for debug: display cllision indormation
showCollision = (collision)->
  console.log "##########################################################"
  for key, value of collision
    switch key
      when "collision"
        null
      when "products"
        for p, i in value
          console.log "####       -> #{i+1}: #{JSON.stringify p}"
      when "patterns"
        [p1,p2] = collision.patterns
        console.log "####   patterns: #{Cells.to_rle p1}, #{Cells.to_rle p2}"
      else
        console.log "####   #{key}: #{JSON.stringify value}"

#### colliding with offset [0,0,0]
#### CP: {"dist":0,"npos0":[0,0,0],"npos1":[0,0,0],"tcoll":0}
#### AP: {"approach":true,"npos0":[-30,0,-180],"npos1":[0,0,-180],"tapp":-180}
#### Collision RLE: $1379bo22$2o2$2o
      

### Calculate the space of all principially different relative positions of 2 patterns
#  Returns:
#     elementaryCell: list of 3-vectors of relative positions
#     freeIndex: index of the coordinate, that changes freely. 0 or 1 for valid patterns
###
determinePatternRelativePositionsSpace = (v1, v2) ->
  [freeIndex, freeOrt] = opposingOrt v1, v2
  #console.log "Free offset direction: #{freeOrt}, free index is #{freeIndex}"
  
  pv1 = removeComponent v1, freeIndex
  pv2 = removeComponent v2, freeIndex
  #console.log "Projected to null-space of free ort:"
  #console.log " PV1=#{pv1}, PV2=#{pv2}"
  
  #s = area2d pv1, pv2
  #console.log "Area of non-free section: #{s}"
  
  ecell = (restoreComponent(v,freeIndex) for v in elementaryCell2d(pv1, pv2))
  if ecell.length isnt Math.abs area2d pv1, pv2
    throw new Error "elementary cell size is wrong"
    
  return{
    elementaryCell: ecell
    freeIndex: freeIndex
    }

### Call the callback for all collisions between these 2 patterns
###
allCollisions = (rule, library, pattern1, pattern2, onCollision) ->
  v2 = (determinePeriod rule, pattern2, 0).delta
  v1 = (determinePeriod rule, pattern1, 0).delta
  console.log "Two velocities: #{v1}, #{v2}"
  {elementaryCell, freeIndex} = determinePatternRelativePositionsSpace v1, v2
  
  #now we are ready to perform collisions
  # free index changes unboundedly, other variables change inside the elementary cell
  
  minimalTouchDistance = (pattern1.length + pattern2.length + 1)*3
  #console.log "#### Minimal touch distance is #{minimalTouchDistance}"

  for offset in elementaryCell
    #dPos, v0, v1, dMax, index
    offsetRange = freeIndexRange offset, v1, v2, minimalTouchDistance, freeIndex
    #console.log "#### FOr offset #{JSON.stringify offset}, index range is #{JSON.stringify offsetRange}"
    
    for xFree in [offsetRange[0] .. offsetRange[1]] by 1
      offset = offset[..]
      offset[freeIndex] = xFree
      if isValidOffset offset
        collision = doCollision rule, library, pattern1, v1, pattern2, v2, offset, minimalTouchDistance*2, minimalTouchDistance
        if collision.collision
          onCollision collision
  return

        
runCollider = ->
  #single rotate - for test
  rule = from_list_elem [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]
  library = new Library rule
  library.load "./singlerot-simple.lib.json"
  
  #2-block
  pattern2 = Cells.from_rle "$2o2$2o"
  pattern1 = Cells.from_rle "o"

  allCollisions rule, library, pattern1, pattern2, (collision) ->
    showCollision collision

makeCollisionCatalog = (rule, library, pattern1, pattern2) ->
  catalog = []
  allCollisions rule, library, pattern1, pattern2, (collision) ->
    #showCollision collision
    catalog.push collision
  return catalog

# Main fgunctons, that reads command line parameters and generates collision catalog
mainCatalog = ->
  stdio = require "stdio"
  opts = stdio.getopt {
    output:
      key: 'o'
      args: 1
      description: "Output file. Default is collisions-[p1]-[p2]-rule.json"
    rule:
      key:'r'
      args: 1
      description: "Rule (16 integers). Default is SingleRotation"
    libs:
      key:"L"
      args: 1
      description: "List of libraries to load. Use : to separate files"
    }, "pattern1 pattern2"

  ################# Parsing options #######################
  unless opts.args? and opts.args.length in [2..2]
    process.stderr.write "Not enough arguments\n"
    process.exit 1
    
  [rle1, rle2] = opts.args    
  pattern1 = Cells.from_rle rle1
  pattern2 = Cells.from_rle rle2
  console.log "#### RLEs: #{rle1}, #{rle2}"
  console.log "Colliding 2 patterns:"
  console.log pattern2string pattern1
  console.log "--------"
  console.log pattern2string pattern2

  rule = if opts.rule?
    parseElementary opts.rule
  else
    from_list_elem [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]
    
  unless rule.is_vacuum_stable()
    throw new Error "Rule is not vacuum-stable. Not supported currently."
  unless rule.is_invertible()
    throw new Error "Rule is not invertible. Not supported currently."
    
  outputFile = if opts.output?
    opts.output
  else
     "collisions-#{normalizedRle pattern1}-#{normalizedRle pattern2}-#{rule.stringify()}.json"
    
  libFiles = if opts.libs?
    opts.libs.split ":"
  else
    []
  ############### Running the collisions ###################
  library = new Library rule
  for libFile in libFiles
    library.load libFile
      
  czs = makeCollisionCatalog rule, library, pattern1, pattern2
  console.log "Found #{czs.length} collisions, stored in #{outputFile}"
  
  fs = require "fs"
  czsData =
    rule: rule.to_list()
    patterns: [pattern1, pattern2]
    collisions: czs
  fs.writeFileSync outputFile, JSON.stringify(czsData), {encoding:"utf8"}

pattern2string = (pattern, signs = ['.', '#']) ->
  [x0, y0, x1, y1] = Cells.bounds pattern
  x0 -= mod2 x0
  y0 -= mod2 y0
  x1 += 1
  y1 += 1
  x1 += mod2 x1
  y1 += mod2 y1
  w = x1 - x0
  h = y1 - y0
  fld = ((signs[0] for i in [0...w]) for j in [0...h])
  for [x,y] in pattern
    fld[y-y0][x-x0] = signs[1]
  return (row.join("") for row in fld).join("\n")
  
#runCollider()
mainCatalog()
