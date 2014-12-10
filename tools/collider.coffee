#!/usr/bin/env coffee

# Particle collider.
# Make collision table

fs = require "fs"
{Cells, inverseTfm, evaluateCellList, getDualTransform, splitPattern} = require "../scripts-src/cells"
{Rule, from_list_elem} = require "../scripts-src/rules"
stdio = require "stdio"
{mod,mod2} = require "../scripts-src/math_util"

library = null

#GIven 2 3-vectors, return 3-ort, that forms full basis with both vectors
opposingOrt = (v1, v2) ->
  for i in [0..2]
    ort = [0,0,0]
    ort[i] = 1
    if isCompleteBasis v1, v2, ort
      return [i, ort]
  throw new Error "Two vectors are collinear"  

dot3 = (a,b) ->
  s = 0
  for i in [0...3]
    s += a[i]*b[i]
  return s
  
#project 3-vector vec to the null-space of ort
projectToNullSpace = (ort, vec) ->
  if dot3(ort,ort) isnt 1
    throw new Error "Not an ort!"
  p = dot3(ort,vec)
  
  return (vec[i] - ort[i]*p for i in [0...3] )

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
  #determinant. copipe from maxima
  det = v1[0]*(v2[1]*v3[2]-v3[1]*v2[2])-v1[1]*(v2[0]*v3[2]-v3[0]*v2[2])+(v2[0]*v3[1]-v3[0]*v2[1])*v1[2]
  return det isnt 0

#Area of a tetragon, built on 2 vectors.
area2d = ([x1,y1],[x2,y2])->
  return x1*y2 - x2*y1

vecSum = (v1, v2) ->   (v1i+v2[i] for v1i, i in v1)
vecDiff = (v1, v2) ->  (v1i-v2[i] for v1i, i in v1)
vecScale = (v1, k) ->  (v1i*k for v1i in v1)

#Returns list of coordinates of points in elementary cell
# both vectors must be 2d, nonzero, non-collinear
elementaryCell = (v1, v2) ->
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

#Calculate time, when 2 spaceship approach to the specified distance.
approachParameters = (pos0, delta0, pos1, delta1, approachDistance) ->
  [dx, dy, dt] = vecDiff pos0, pos1
  [vx0, vy0, p0] = delta0
  [vx1, vy1, p1] = delta1


  #solve( [deltax^2 + deltay^2 = dd^2, deltat=0], [a,b] );
  dd = approachDistance
  D = (p0**2*vy1**2-2*p0*p1*vy0*vy1+p1**2*vy0**2+p0**2*vx1**2-2*p0*p1*vx0*vx1+p1**2*vx0**2)
  #thanks maxima. 
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

normalizedRle = (fld) ->
  ff = Cells.copy fld
  Cells.normalize ff
  Cells.to_rle ff
  

evalToTime = (rule, fld, t0, tend) ->
  if t > tend then throw new Error "assert: bad time"
  for t in [t0 ... tend] by 1
    fld = evaluateCellList rule, fld, mod2(t)
  return fld

#put the pattern to the specified time and position, and return its state at time t
patternAtTime = (rule, pattern, posAndTime, t) ->
  pattern = Cells.copy pattern
  [x0,y0,t0] = posAndTime
  Cells.offset pattern, x0, y0
  evalToTime rule, pattern, t0, t
  
# Collide 2 patterns: p1 and p2,
#    p1 at [0,0,0] and p2 at `offset`.
#    initialSeparation::int approximate initial distance to put patterns at. Should be large enought for patterns not to intersect
#    offset: [dx, dy, dt] - initial offset of the pattern p2 (p1 at 000)
#    collisionTreshold:: if patterns don't come closer than this distance, don't consider them colliding.
#    waitForCollision::int How many generations to wait after the approximate nearest approach, until the interaction would start.
#
#  Returned value: object
#    collision::bool true if collision
#    timeStart::int first generation, where interaction has started
#    products::[ ProductDesc ]  list of collision products (patterns with their positions and classification
doCollision = (rule, p1, v1, p2, v2, offset, initialSeparation = 30, collisionTreshold=20)->
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
  fld1 = patternAtTime rule, p1, ap.npos0, time
  fld2 = patternAtTime rule, p2, ap.npos1, time
  
  #OK, collision prepared. Now simulate both spaceships separately and
  # together, waiting while interaction occurs
  timeGiveUp = params.tcoll + waitForCollision #when to stop waiting for some interaction
  coll = simulateUntilCollision rule, fld1, fld2, time, timeGiveUp
  
  if not coll.collided
    #console.log "#### No interaction detected until T=#{timeGiveUp}. Give up."
    return collision
    
  console.log "#### colliding:"
  console.log "#### 1)  #{normalizedRle p1} at [0, 0, 0]"
  console.log "#### 2)  #{normalizedRle p2} at {JSON.stringify offset}"
  console.log "####     collision at T=#{coll.time}  (give up at #{timeGiveUp})"
  collision.timeStart = coll.time
  collision.collision = true
  timeCollisionStart = coll.time
  
  fld1 = fld2 = null #They are not needed anymore
  
  collision.products = finishCollision rule, coll.field, coll.time
  return collision

#Simulate 2 patterns until they collide.
# Return first oment of time, when patterns started interacting.
simulateUntilCollision = (rule, fld1, fld2, time, timeGiveUp) ->
  fld  = fld1.concat fld2  
  while time < timeGiveUp
    phase = mod2 time
    fld1 = evaluateCellList rule, fld1, phase
    fld2 = evaluateCellList rule, fld2, phase
    fld  = evaluateCellList rule, fld,  phase
    time += 1
    #check if they are different
    fld12 = fld1.concat fld2
    Cells.sortXY fld
    Cells.sortXY fld12
    if not Cells.areEqual fld, fld12
      return {
        collided: true
        time: time
        field: fld
      }
  return{
    collided: false
  }

#simulate patern until it decomposes into several simple patterns
# Return list of collision products
finishCollision = (rule, field, time) ->
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
      break
  #now try to split result into several patterns
  parts = separatePatternParts field
  console.log "#### Detected #{parts.length} parts"
  if parts.length is 1
    console.log "#### only one part, try more time"
    return finishCollision rule, field, time
  for part, i in parts
    console.log "####   #{i}. #{normalizedRle part}"
    #now analyze this part
    res = analyzeFragment rule, part, time

    

analyzeFragment = (rule, pattern, time, options={})->
  analysys = determinePeriod rule, pattern, time, options
  if analysys.cycle
    console.log "####      Pattern analysys: #{JSON.stringify analysys}"
    res = library.classifyPattern pattern, time, analysys.delta...
    console.log "####      Classification: #{JSON.stringify res}"
    
#detect periodicity in pattern
# Returns :
#   cycle::bool - is cycle found
#   error::str - if not cycle, says error
#   delta::[dx, dy, dt] - velocity and period, if cycle
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
  addPattern: (pattern, delta) ->
    rle = Cells.to_rle pattern
    if @rle2pattern.hasOwnProperty rle
      throw new Error "Pattern already present: #{rle}"
    @rle2pattern[rle] = delta
    
  addRle: (rle) ->
    pattern = Cells.from_rle rle
    analysys = determinePeriod @rule, pattern, 0
    if not analysys.cycle then throw new Error "Pattern #{rle} is not periodic!"
    console.log "#### add anal: #{JSON.stringify analysys}"
    [dx,dy,p]=delta=analysys.delta
    unless (dx>0 and dy>=0) or (dx is 0 and dy is 0)
      throw new Error "Pattern #{rle} moves in wrong direction: #{dx},#{dy}"
    @addPattern pattern, delta
      
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
        if result.found
          result.transform = inverseTfm tfm
          break
    #reverse-transform position
    [x,y,t] = result.pos
    #console.log "#### Original pos: #{JSON.stringify result.pos}"
    [x,y] = Cells.transformVector [x,y], result.transform, false #no normalize!
    #console.log "#### after inverse rotate: #{JSON.stringify [x,y,t]}"
    result.pos = [x,y,t]
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
      if self.rle2pattern.hasOwnProperty rle
        #console.log "####      found! #{rle}"
        result.pos = [dx, dy, t]
        result.rle = rle
        result.found=true
        return false
      return (t-time) < period
    return result
    

#geometrically separate pattern into several parts
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

#single rotate - for test
rule = from_list_elem [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]

#2-block
pattern2 = Cells.from_rle "$2o2$2o"
pattern1 = Cells.from_rle "o"

v2 = (determinePeriod rule, pattern2, 0).delta
v1 = (determinePeriod rule, pattern1, 0).delta

library = new Library rule
library.addRle "$2o2$2o"
library.addRle "bo$2b2o$3bo"
library.addRle "2bobo$b2o"
library.addRle "b2o2$2o"
library.addRle "bo$bo$2o"
library.addRle "o$o2$o$o"

library.addRle "o"
library.addRle "oo"

console.log "Two velocities: #{v1}, #{v2}"
[freeIndex, freeOrt] = opposingOrt v1, v2
console.log "Free offset direction: #{freeOrt}, free index is #{freeIndex}"

pv1 = removeComponent v1, freeIndex
pv2 = removeComponent v2, freeIndex
console.log "Projected to null-space of free ort:"
console.log " PV1=#{pv1}, PV2=#{pv2}"

s = area2d pv1, pv2
console.log "Area of non-free section: #{s}"

ecell = (restoreComponent(v,freeIndex) for v in elementaryCell(pv1, pv2))
console.log "Elementary cell size: #{ecell.length}"
for p, i in ecell
  console.log "  #{i}: " + JSON.stringify(p)

#now we are ready to perform collisions
# free index changes unboundedly, other variables change inside the elementary cell

offsetRange = [-40, 30]

for xFree in [offsetRange[0] .. offsetRange[1]] by 1
  for offset in ecell
    offset = offset[..]
    offset[freeIndex] = xFree
    if isValidOffset offset
      doCollision rule, pattern1, v1, pattern2, v2, offset


#### colliding with offset [0,0,0]
#### CP: {"dist":0,"npos0":[0,0,0],"npos1":[0,0,0],"tcoll":0}
#### AP: {"approach":true,"npos0":[-30,0,-180],"npos1":[0,0,-180],"tapp":-180}
#### Collision RLE: $1379bo22$2o2$2o
      
