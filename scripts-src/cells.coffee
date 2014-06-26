#//////////////////////////////////////////////////////////////////////////////
# Configuration analysis
#//////////////////////////////////////////////////////////////////////////////
#Import section
module_rle = require "./rle"
module_rules = require "./rules"
module_math_util = require "./math_util"
module_reversible_ca = require "./reversible_ca"

{parse_rle} = module_rle
{Rule, Bits} = module_rules
{Maximizer, mod2} = module_math_util
{MargolusNeighborehoodField, Array2d} = module_reversible_ca

exports.Cells = Cells =
  #Collection of methodw for working with cell lists
  areEqual: (l1, l2) ->
    return false  if l1.length isnt l2.length
    for i in [0...l1.length] by 1
      xy1 = l1[i]
      xy2 = l2[i]
      return false if xy1[0] isnt xy2[0] or xy1[1] isnt xy2[1]
    true

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
    return null
  ###
  Convert list of alive cells to RLE. List of cells must be sorted by Y, then by X, and coordinates of origin must be at (0,0)
  ###
  to_rle: (cells) ->
    #COnvert sorted (by y) list of alive cells to RLE encoding
    rle = ""
    count = 0
    
    appendNumber = (n, c) ->
      rle += n  if n > 1
      rle += c

    endWritingBlock = ->
      if count > 0
        appendNumber count, "o"
        count = 0

    x = -1
    y = 0
 
    for [xi, yi], i in cells
      dy = yi - y
      throw new Error "Cell list are not sorted by Y"  if dy < 0
      
      if dy > 0 #different row
        endWritingBlock()
        appendNumber dy, "$"
        x = -1
        y = yi
      dx = xi - x
      throw new Error "Cell list is not sorted by X"  if dx <= 0
      if dx is 1
        count++ #continue current horizontal line
      else if dx > 1 #line broken
        endWritingBlock()
        appendNumber dx - 1, "b"  #write whitespace before next block
        count = 1 #and remember the current cell
      x = xi
    endWritingBlock()
    rle

  ###
  Convert RLE-encoded configutaion back to cell list
  ###
  from_rle: (rle) ->
    cells = []
    parse_rle rle, (x, y) -> cells.push [x, y]
    cells

  #
  #var cc=[[1,0],[2,0],[2,1],[2,2]];
  #//   0123
  #// 0  ##
  #// 1   #
  #// 2   #
  #var rle_=cellList2Rle(cc);
  #var rle_expect="b2o$2bo$2bo";
  #if (rle_ !== rle_expect){
  #    alert("RLE wrong:"+rle_+"\nExpected:"+rle_expect);
  #}
  #
  #

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

  _rotations: [[1, 0, 0, 1], [0, 1, -1, 0], [-1, 0, 0, -1], [0, -1, 1, 0]] #Different rotations
  
  _find_normalizing_rotation: (dx, dy) ->
    for t in @_rotations
      dx1 = dx * t[0] + dy * t[1]
      dy1 = dx * t[2] + dy * t[3]
      if dx1 > 0 and dy1 >= 0 #important: different comparisions
        return [dx1, dy1, t]
    throw new Error "Impossible to rotate vector (#{dx},#{dy}) to the positive direction"

  analyze: (pattern, rule, options={}) ->
    throw new Error ("Pattern undefined")  unless pattern
    throw new Error ("Rule undefined")  unless rule

    max_iters = options.max_iters ? 2048
    max_population = options.max_population ? 1024
    max_size = options.max_size ? 1024
    
    snap_below = (x,generation) ->
      x - mod2(x + generation)
                        
    offsetToOrigin = (pattern, bounds, generation) ->
      [x0,y0] = bounds
      x0 = snap_below x0, generation
      y0 = snap_below y0, generation
      Cells.offset pattern, -x0, -y0
      return [pattern, x0, y0]

    stable_rules = rule.stabilize_vacuum()
    vacuum_period = stable_rules.size() #ruleset size
    pattern = @normalize pattern
                
    #Shift pattern to the origin
    [pattern] = offsetToOrigin pattern, Cells.bounds(pattern), 0
                
    bestPatternSearch = new Maximizer @energy
    bestPatternSearch.put pattern
    
    #start search
    cycle_found = false
    curPattern = pattern
    dx = 0
    dy = 0
    #console.log "####Analyze pattern #{ Cells.to_rle curPattern }"
    result = {
      analyzed_generations: max_iters
      resolution: "iterations exceeded"
    }
    for iter in [vacuum_period .. max_iters] by vacuum_period
      #TODO: evaluate cell list, always assuming initial, 0 phase
      phase = 0
      for stable_rule in stable_rules.rules
        curPattern = evaluateCellList stable_rule, curPattern, phase
        phase ^= 1
        
      @sortXY curPattern
      #console.log "#### Iter #{ iter }\t:  #{ @to_rle @normalizeXY curPattern[..] }"
      #After evaluation, pattern is in phase 1. remove offset and transform back to phase 0
      bounds = Cells.bounds curPattern
      [curPattern, x0, y0] = offsetToOrigin curPattern, bounds, phase
      dx += x0
      dy += y0
      
      if @areEqual pattern, curPattern
        cycle_found = true
        result.resolution = "cycle found"
        break
      bestPatternSearch.put curPattern
      if curPattern.length > max_population
        result.resolution = "pattern grew too big"
        break
      if Math.max( bounds[2]-bounds[0], bounds[3]-bounds[1]) > max_size
        result.resolution = "pattern dimensions grew too big"
        break

    #Return results
    cells_best = bestPatternSearch.getArg() 
    if cycle_found
       [cells_best, result.dx, result.dy] =
         @canonicalize_spaceship cells_best, rule, dx, dy
       result.period = iter
    result.cells = cells_best
    return result
                    
  #Given a spaceship and its direction,
  # Rotate it, if rule is invariant in relation to rotation
  canonicalize_spaceship: (pattern, rule, dx, dy) ->
    if dx isnt 0 or dy isnt 0 #If it is a spaceship
      if rule.is_transposable_with(Bits.rotate) #And if the rule allows rotation by 90
        [dx, dy, t] = @_find_normalizing_rotation dx, dy
        pattern = @transform pattern, t
    [pattern, dx, dy]
    
  #For the given spaceship, returns its dual, if rule has duality transform
  #Returned spaceship is rotated to have positive direction, if rule has rotation symmetry
  # Return value: [pattern, dx1, dy1]
  getDualSpaceship: (pattern, rule, dx, dy) ->
    [name,tfm,_] = getDualTransform rule
    if name is null then return [null] #No duality transform
    dualPattern = Cells.togglePhase Cells.transform pattern, tfm
    dx1 = -(dx * tfm[0] + dy * tfm[1])
    dy1 = -(dx * tfm[2] + dy * tfm[3])
    Cells.canonicalize_spaceship dualPattern, rule, dx1, dy1

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



###
# Calculates next generation of the cell list, without using field.
# Coordinates are not limited.
# List must contain 3-tuples: x,y,v; where v!=0
###
exports.evaluateLabelledCellList = evaluateLabelledCellList = (ruleObj, cells, phase, on_join_labels=null) ->
  rule = ruleObj.table
  if rule[0] isnt 0
    throw new Error "Rule has instable vacuum and not supported."
  #Group cells into blocks by 4
  # Indices are:
  # 0 1
  # 2 3
  block2cells = {} #block key -> [val1, val2, val3, val4, block_index_x, block_index_y]
  
  #Collect cells by blocks
  for [x,y,v] in cells
    x+=phase
    y+=phase
    dx = x&1 #faser than mod(x,2)... I hope.
    dy = y&1
    idx = dx + dy*2 #Index of this cell in the block
    b_x = x>>1 #faster than div(x,2)
    b_y = y>>1
    key = ""+b_x+" "+b_y
    block = block2cells[key] ? (block2cells[key] = [0,0,0,0, b_x, b_y])
    block[idx]=v
    
  #Transform and de-collect them
  transformed = []
  for key, [a,b,c,d, b_x, b_y] of block2cells
    b_x = (b_x<<1) - phase
    b_y = (b_y<<1) - phase
    y_code = rule[ (a isnt 0) + ((b isnt 0)<<1) + ((c isnt 0)<<2) + ((d isnt 0)<<3) ]
    #merged_label = Math.max(Math.max(a,b), Math.max(c,d))
    merged_label = a or b or c or d
    if y_code & 1
      transformed.push [b_x, b_y, merged_label]
    if y_code & 2
      transformed.push [b_x+1, b_y, merged_label]
    if y_code & 4
      transformed.push [b_x, b_y+1, merged_label]
    if y_code & 8
      transformed.push [b_x+1, b_y+1, merged_label]
    #register joined cell labels
    if on_join_labels?
      #no need to check with a, since it is either 0 or equals to merged_label
      if a and (a isnt merged_label) then on_join_labels merged_label, a
      if b and (b isnt merged_label) then on_join_labels merged_label, b
      if c and (c isnt merged_label) then on_join_labels merged_label, c
      if d and (d isnt merged_label) then on_join_labels merged_label, d
  transformed

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
      

      
exports.evaluateCellList = evaluateCellList = (ruleObj, cells, phase) ->
  rule = ruleObj.table
  if rule[0] isnt 0
    throw new Error "Rule has instable vacuum and not supported."
  #Group cells into blocks by 4
  # Indices are:
  # 0 1
  # 2 3
  block2cells = {} #block key -> [block state, block_index_x, block_index_y]
  
  #Collect cells by blocks
  for [x,y] in cells
    x+=phase
    y+=phase
    #indices of a block
    b_x = x >> 1
    b_y = y >> 1
    #block key
    key = ""+b_x+" "+b_y
    
    block = block2cells[key] ? (block2cells[key] = [0, b_x, b_y])
    #put this cell to the block
    block[0] |= (1 << ((x&1) + (y&1)*2))
    
  #Transform and de-collect them
  transformed = []
  for _, [x_code, b_x, b_y] of block2cells
    b_x = (b_x<<1) - phase
    b_y = (b_y<<1) - phase
    #Get transformed block state
    y_code = rule[ x_code ]
    #and decompose block into separate cells
    if y_code & 1
      transformed.push [b_x, b_y]
    if y_code & 2
      transformed.push [b_x+1, b_y]
    if y_code & 4
      transformed.push [b_x, b_y+1]
    if y_code & 8
      transformed.push [b_x+1, b_y+1]
  transformed


#private
extend_array = (arr, arr1) ->
  for x in arr1
    arr.push x
  arr

####
# Splits pattern into several parts, that do not interact.
# 
exports.splitPattern = (rule, pattern, steps) ->
  label2group = {}
  group2labels = {}
  labelled_pattern = []
  ruleset = rule.stabilize_vacuum()
  #First, add label to each cell,
  #  and create individual group for each label.
  for [x,y], i in pattern
    label = i+1
    labelled_pattern.push [x,y,label]
    label2group[label] = label
    group2labels[label] = [label]
  number_of_groups = pattern.length

    
  #Merge two labels, marking that they belong to the same group
  merge_labels = (lab1, lab2) ->
    grp1 = label2group[lab1]
    grp2 = label2group[lab2]
    if grp1 isnt grp2
      #OK, labels belong to the different groups.
      # Merge them: now grp1 consumes grp2
      grp1_labels = group2labels[grp1] 
      grp2_labels = group2labels[grp2]
      if not grp1_labels? or not grp2_labels?
        throw new Error "assertion: group has no labels"
      #Merge labels lists
      extend_array grp1_labels, grp2_labels
      #clear unused entity
      delete group2labels[grp2]
      #mark all labels, belonged to grp2, as belonging to grp1
      for label in grp2_labels
        label2group[label] = grp1
      number_of_groups -= 1
    null
  
  #assume that initial phase is 0
  ruleset_phase = 0 
  #Evaluate pattern for the given number of steps,
  # or until it merges completely.
  for iter in [0..steps] by 1
    labelled_pattern = evaluateLabelledCellList ruleset.rules[ruleset_phase], labelled_pattern, (iter%2), merge_labels
    ruleset_phase = (ruleset_phase+1)%ruleset.size()
    if number_of_groups <= 1 #Reached total merge before complete evaluation
      break
  #Now just construct the result: list of patterns (list of lists)
  return (
    for grp_key, labels of group2labels
      grp = parseInt grp_key, 10
      for label in labels
        pattern[ parseInt(label,10)-1 ])
