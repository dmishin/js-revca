#//////////////////////////////////////////////////////////////////////////////
# Patterns
#//////////////////////////////////////////////////////////////////////////////
#Import section
{parse_rle, to_rle} = require "./rle"
{mod2} = require "./math_util"

exports.Cells = Cells =
  #Collection of methodw for working with cell lists
  areEqual: (l1, l2) ->
    return false  if l1.length isnt l2.length
    for i in [0...l1.length] by 1
      xy1 = l1[i]
      xy2 = l2[i]
      return false if xy1[0] isnt xy2[0] or xy1[1] isnt xy2[1]
    true

  shiftEqual: (p1, p2, oddity) ->
    return null if p1.length isnt p2.length
    return [oddity, oddity] if p1.length is 0
    [x0, y0] = p1[0]
    [x1, y1] = p2[0]
    dx = x1-x0
    dy = y1-y0
    if (mod2(dx+oddity) isnt 0) or mod2(dy+oddity) isnt 0
      return null #wrong oddity
    
    for i in [1...p1.length] by 1
      [x0, y0] = p1[i]
      [x1, y1] = p2[i]
      if (x1-x0 isnt dx) or (y1-y0 isnt dy)
        return null
    return [dx,dy]
    
  copy: (lst) -> ( xy[..] for xy in lst )
  #Sort list of cells, first by X then by Y
  sortXY: (lst) ->
    lst.sort ([x1,y1],[x2,y2]) -> (y1-y2) or (x1-x2)

  #Returns bounds (inclusive) for the cell list
  bounds: (lst) ->
    return [0, 0, 0, 0]  if lst.length is 0
    [x1, y1] = [x0, y0] = lst[0]
    for i in [1 ... lst.length] by 1
      [x,y] = lst[i]
      x0 = Math.min(x0, x)
      x1 = Math.max(x1, x)
      y0 = Math.min(y0, y)
      y1 = Math.max(y1, y)
    [x0, y0, x1, y1]

  #Returns bounds (inclusive) for the cell list
  topLeft: (lst) ->
    return [0, 0]  if lst.length is 0
    [x0, y0] = lst[0]
    for i in [1 ... lst.length] by 1
      [x,y] = lst[i]
      x0 = Math.min(x0, x)
      y0 = Math.min(y0, y)
    return [x0, y0]
  
  transform: (lst, tfm, need_normalize = true) ->
    #transform cell block: rotate or flip
    [t00, t01, t10, t11] = tfm
    lst1 = for [x,y] in lst
      x += 0.5
      y += 0.5
      x1 = (t00 * x + t01 * y - 0.5) | 0
      y1 = (t10 * x + t11 * y - 0.5) | 0
      [x1, y1]
    if need_normalize
      @normalize lst1
    else
      lst1
        
  #Normalize list: sort cells and offset them to the origin    
  normalize: (lst1) -> @sortXY @normalizeXY lst1
  
  #Move cells to origin    
  normalizeXY: (lst1) ->
    [xmin, ymin] = @bounds lst1
    xmin -= mod2 xmin
    ymin -= mod2 ymin
    @offset lst1, -xmin, -ymin

  #Shift all cells by 1 and normalize coordinates
  togglePhase: (cells) ->
    cells1 = ([x+1,y+1] for [x,y] in cells)
    Cells.normalizeXY cells1
      
  #inplace offset
  offset: (lst, dx, dy) ->
    for xy in lst
      xy[0] += dx
      xy[1] += dy
    lst
    
  #Low-bottom margin, inclusive
  extent: (lst) ->
    [_,_,x1, y1] = @bounds lst
    [x1, y1]

  #Find index of the first cell with given coordinates    
  find: (lst, [x,y]) ->
    for [xi, yi], i in lst
      if xi is x and yi is y
        return i
    return
    
  ###
  Convert list of alive cells to RLE. List of cells must be sorted by Y, then by X, and coordinates of origin must be at (0,0)
  ###
  to_rle: to_rle

  ###
  Convert RLE-encoded configutaion back to cell list
  ###
  from_rle: (rle) ->
    cells = []
    parse_rle rle, (x, y) -> cells.push [x, y]
    cells

  #Energy fucntion to calculate canonical form
  # Energy is bigger for the more compact configurations.
  energy: (lst) ->
    n = lst.length
    e = 0
    for [x1,y1], i in lst
      for j in [i+1 ... n]
        [x2,y2] = lst[j]
        e += 1.0 / Math.pow(Math.pow(x1 - x2, 2) + Math.pow(y1 - y2, 2), 0.25)
    [x0,y0,x1,y1] = Cells.bounds lst
    e/((x1-x0+1)*(y1-y0+1))

  energy1: (lst) ->
    xy2item = {}
    xs = 0
    ys = 0
    for [x,y] in lst
      xy2item["#{x}$#{y}"]=true
      xs += x
      ys += y
    xs /= lst.length
    ys /= lst.length
    #weighted number of neighbores. 2 for the diagonal ones and 3 for the orthogonal
    # Total max is 3*4+2*4 = 20.
    numneigh = (x,y)->
      s = 0
      for dx in [-1 .. 1]
        for dy in [-1..1]
          if (dx is 0) and (dy is 0)
            continue
          if xy2item["#{x+dx}$#{y+dy}"]
            s += if ((dx is 0) or (dy is 0)) then 3 else 2
      return s
    #the more "alone" the point is, the more energy it has.
    # also, the farther it is from the center, the more energy it has
    e = 0
    for [x,y] in lst
      #d = Math.abs(x-xs) + Math.abs(y-ys)
      #e += d / (numneigh(x,y)+1)
      e += 1 / (numneigh(x,y)+1)

    #reduce energy for the symmetric patterns
    is_symmetric = (kx, ky, flp)->
      for [x,y] in lst
        dx = x-xs
        dy = y-ys
        if flp
          tmp=dx
          dx =dy
          dy=tmp
        xt = (xs + dx*kx) | 0
        yt = (ys + dy*ky) | 0
        if not xy2item["#{xt}$#{yt}"]
          return false
      return true
      
    symmetries = 0
    if is_symmetric(1,-1,false)
      symmetries += 1
    if is_symmetric(-1,1, false)
      symmetries += 1
    if is_symmetric(1,1,true)
      symmetries += 1
    if is_symmetric(-1,-1,true)
      symmetries += 1
    if is_symmetric(-1,-1, false)
      symmetries += 1
    
    #finally,prefer the patterns that are grouped in a small area.
    #[x0,y0,x1,y1] = Cells.bounds lst
    #return -e*((x1-x0+1)*(y1-y0+1))
    #the more symmetries it has, the less is symmetry energy
    return -(e + (30000)/(symmetries + 1)) #10000 is the weight of a symmetry factor

  _rotations: [[1, 0, 0, 1], [0, 1, -1, 0], [-1, 0, 0, -1], [0, -1, 1, 0]] #Different rotations

  transformVector: ([dx,dy], t) ->
    [dx * t[0] + dy * t[1],
     dx * t[2] + dy * t[3]]
    
  _find_normalizing_rotation: (dx, dy) ->
    for t in @_rotations
      [dx1, dy1] = @transformVector [dx, dy], t
      if dx1 > 0 and dy1 >= 0 #important: different comparisions
        return [dx1, dy1, t]
    throw new Error "Impossible to rotate vector (#{dx},#{dy}) to the positive direction"

  

#Operations over 2d points
exports.Point = Point =
  equal: ([x0,y0],[x1,y1])->
    x0 is x1 and y0 is y1
  subtract: ([x0,y0],[x1,y1])->
    [x0-x1, y0-y1]
  add: ([x0,y0],[x1,y1])->
    [x0+x1, y0+y1]
  isZero: ([x,y]) -> x is 0 and y is 0
  scale: ([x,y], k) -> [x*k, y*k]
  scaleRound: ([x,y], k) -> [x*k |0, y*k |0]
  corners: ([xa,ya],[xb,yb]) ->
    [ [Math.min(xa, xb), Math.min(ya, yb)],
      [Math.max(xa, xb), Math.max(ya, yb)] ]
  boundBox: ([xa,ya],[xb,yb]) ->
    [ Math.min(xa, xb), Math.min(ya, yb),
      Math.max(xa, xb)+1, Math.max(ya, yb)+1 ]
  updateBoundBox: (bbox, [x,y]) ->
    bbox[0] = Math.min bbox[0], x
    bbox[1] = Math.min bbox[1], y
    bbox[2] = Math.max bbox[2], x
    bbox[3] = Math.max bbox[3], y
    bbox




#Returns array of 16 items: transposition of possible bit block values,
# induced by the affine transform.       
exports.transformMatrix2BitBlockMap = transformMatrix2BitBlockMap = (tfm) ->
  boxPoints = [[-1,0], [0,0], [-1,-1], [0,-1]] #Coordinates of cells inside one block; assuming that rotation center is at (-1/2, -1/2)
  boxPointsT = Cells.transform boxPoints, tfm, false  #need_normalize
  tfmCellIndex = (i) ->
    Cells.find boxPoints, boxPointsT[i] #Find index of the transformed point

  #How the transofmration matrix trasnposes cells in the 2x2 block
  cellsTransposition = ( tfmCellIndex(i) for i in [0..3] )
  #Transform bit block (value in the range 0..16).
  tfmBitBlock = (x)->
    y = 0 
    for i in [0..3] when (x >> i) & 1
      y = y | (1 << cellsTransposition[i] ) #add mask of the transformed point to the output
    return y
  return (tfmBitBlock(i) for i in [0..15])

tfmRecord = (name, mtx) -> [name, mtx, transformMatrix2BitBlockMap mtx]
transforms = [
  tfmRecord("iden",   [1,0,0,1 ]),
  tfmRecord("rot90",  [0,1,-1,0]),
  tfmRecord("rot180", [-1,0,0,-1]),
  tfmRecord("rot270", [0,-1,1,0]),
  tfmRecord("flipx",  [-1,0,0,1]),
  tfmRecord("flipy",  [1,0,0,-1]),
  tfmRecord("flipxy", [0,1,1,0]),
  tfmRecord("flipixy",[0,-1,-1,0])]

exports.inverseTfm = inverseTfm = (tfm) ->
  [a00,a01, a10,a11] = tfm
  d = a00*a11 - a01*a10
  if d is 0 then throw new Error "Singular matrix"
  id = 1/d
  return [a11*id, -a01*id, -a10*id, a00*id]

#Returns dual transformation matrix, or none, if dual transform does not exists
# Matrix is returned as array of 4 elements, [t00, t01, t10, t11]
exports.getDualTransform = getDualTransform = (rule)->
    #All possible transfomation matrices and their names
    isDualBlockTfm = (f, t, name) ->
      # check that
      # T F T^-1 === F^-1
      #   (i.e. duality condition)
      # It can be re-forlumated as:
      # FTF === T
      for x in [0..15]
        if f[t[f[x]]] isnt t[x]
          return false
      return true
    possibleTfms = transforms[..]
    for elemRule in rule.rules
      filtered = []
      for record in possibleTfms
        [name, tfm, blockTfm] = record
        if isDualBlockTfm elemRule.table, blockTfm, name
          #Dual transform for elementary rule found!
          filtered.push record
      possibleTfms = filtered
    if possibleTfms.length > 0
      return possibleTfms[0]
    else
      return [null]
