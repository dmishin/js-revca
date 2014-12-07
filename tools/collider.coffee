#!/usr/bin/env coffee

# Particle collider.
# Make collision table

fs = require "fs"
{Cells, evaluateCellList, getDualTransform, splitPattern} = require "../scripts-src/cells"
{Rule, from_list_elem} = require "../scripts-src/rules"
stdio = require "stdio"
{mod2} = require "../scripts-src/math_util"



#single rotate - for test
rule = from_list_elem [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]

#2-block
pattern1 = Cells.from_rle "$2o2$2o"
v1 = [2, 0, 12] #dx, dy, p

#1-cell
pattern2 = [[1,1]]
v2 = [0, 0, 4]


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

approachParameters = (pos0, delta0, pos1, delta1, approachDistance) ->
  #Calculate time, when 2 spaceship approach to the specified distance.
  [dx, dy, dt] = vecDiff pos0, pos1
  [vx0, vy0, p0] = delta0
  [vx1, vy1, p1] = delta1


  #solve( [deltax^2 + deltay^2 = dd^2, deltat=0], [a,b] );
  dd = approachDistance
  D = (p0**2*vy1**2-2*p0*p1*vy0*vy1+p1**2*vy0**2+p0**2*vx1**2-2*p0*p1*vx0*vx1+p1**2*vx0**2)

  Q2 = (-dt**2*vx0**2+2*dt*dx*p0*vx0+(dd**2-dx**2)*p0**2)*vy1**2+(((2*dt**2*vx0-2*dt*dx*p0)*vx1-2*dt*dx*p1*vx0+(2*dx**2-2*dd**2)*p0*p1)*vy0+(2*dx*dy*p0**2-2*dt*dy*p0*vx0)*vx1+2*dt*dy*p1*vx0**2-2*dx*dy*p0*p1*vx0)*vy1+(-dt**2*vx1**2+2*dt*dx*p1*vx1+(dd**2-dx**2)*p1**2)*vy0**2+(2*dt*dy*p0*vx1**2+(-2*dt*dy*p1*vx0-2*dx*dy*p0*p1)*vx1+2*dx*dy*p1**2*vx0)*vy0+(dd**2-dy**2)*p0**2*vx1**2+(2*dy**2-2*dd**2)*p0*p1*vx0*vx1+(dd**2-dy**2)*p1**2*vx0**2

  if Q2 < 0
    #Approach not possible
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
    npos0 : npos0
    npos1 : npos1
    tapp : tapp
  }

normalizedRle = (fld) ->
  ff = Cells.copy fld
  Cells.normalize ff
  Cells.to_rle ff
  
  

doCollision = (rule, p1, v1, p2, v2, offset, startDist = 30, collisionTreshold=10, waitForCollision=10)->
  params = collisionParameters [0,0,0], v1, offset, v2  
  ap = approachParameters [0,0,0], v1, offset, v2, startDist
  if not ap.approach
    #console.log "#### No approach, nearest approach: #{params.dist}"
    return
  if params.dist > collisionTreshold
    #console.log "#### Too far, nearest approach #{params.dist} > #{collisionTreshold}"
    return
  #console.log "#### colliding with offset #{JSON.stringify offset}"
  #console.log "#### CP: #{JSON.stringify params}"
  #console.log "#### AP: #{JSON.stringify ap}"
  
  #Create the initial field. Put 2 patterns: p1 and p2 at initial time 
  fld1 = Cells.copy p1
  fld2 = Cells.copy p2
  
  Cells.offset fld1, ap.npos0[0], ap.npos0[1]
  Cells.offset fld2, ap.npos1[0], ap.npos1[1]
  
  time1 = ap.npos0[2]
  time2 = ap.npos1[2]

  #nwo promote them to the same time, using list evaluation
  tmax = Math.max time1, time2
  
  evalToTime = (fld, t, tend) ->
    if t > tend then throw new Error "assert: bad time"
    while t < tend
      fld = evaluateCellList rule, fld, mod2(t)
      t += 1
    return fld
    
  fld1 = evalToTime fld1, time1, tmax
  fld2 = evalToTime fld2, time2, tmax
  time = tmax

  #OK, collision prepared. Now simulate both spaceships separately and
  # together, waiting while interaction occurs
  timeGiveUp = params.tcoll + waitForCollision #when to stop waiting for some interaction
  coll = simulateUntilCollision rule, fld1, fld2, time, timeGiveUp
  
  if not coll.collided
    #console.log "#### No interaction detected until T=#{timeGiveUp}. Give up."
    return
  #console.log "#### Got hit at T=#{coll.time}  (give up at #{timeGiveUp})"
  timeCollisionStart = coll.time
  
  fld1 = fld2 = null #They are not needed anymore
  
  finishCollision rule, coll.field, time

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
finishCollision = (rule, field, time) ->
  console.log "#### Collision RLE: #{normalizedRle field}"
  
        
#in margolus neighborhood, not all offsets produce the same pattern
isValidOffset = ([dx, dy, dt]) -> ((dx+dt)%2 is 0) and ((dy+dt)%2 is 0)
############################

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
      