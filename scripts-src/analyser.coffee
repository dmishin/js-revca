{Rule, Bits} = require "./rules"
{Cells, getDualTransform} = require "./cells"
{Maximizer, mod2} = require "./math_util"


exports.analyze = analyze = (pattern, rule, options={}) ->
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
    pattern = Cells.normalize pattern
                
    #Shift pattern to the origin
    [pattern] = offsetToOrigin pattern, Cells.bounds(pattern), 0
                
    bestPatternSearch = new Maximizer Cells.energy
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
        
      Cells.sortXY curPattern
      #console.log "#### Iter #{ iter }\t:  #{ Cells.to_rle Cells.normalizeXY curPattern[..] }"
      #After evaluation, pattern is in phase 1. remove offset and transform back to phase 0
      bounds = Cells.bounds curPattern
      [curPattern, x0, y0] = offsetToOrigin curPattern, bounds, phase
      dx += x0
      dy += y0
      
      if Cells.areEqual pattern, curPattern
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
         canonicalize_spaceship cells_best, rule, dx, dy
       result.period = iter
    result.cells = cells_best
    return result
                    
  #Given a spaceship and its direction,
  # Rotate it, if rule is invariant in relation to rotation
exports.canonicalize_spaceship = canonicalize_spaceship = (pattern, rule, dx, dy) ->
    if dx isnt 0 or dy isnt 0 #If it is a spaceship
      if rule.is_transposable_with(Bits.rotate) #And if the rule allows rotation by 90
        [dx, dy, t] = Cells._find_normalizing_rotation dx, dy
        pattern = Cells.transform pattern, t
    [pattern, dx, dy]
    
  #For the given spaceship, returns its dual, if rule has duality transform
  #Returned spaceship is rotated to have positive direction, if rule has rotation symmetry
  # Return value: [pattern, dx1, dy1]
exports.getDualSpaceship = getDualSpaceship = (pattern, rule, dx, dy) ->
    [name,tfm,_] = getDualTransform rule
    if name is null then return [null] #No duality transform
    dualPattern = Cells.togglePhase Cells.transform pattern, tfm
    dx1 = -(dx * tfm[0] + dy * tfm[1])
    dy1 = -(dx * tfm[2] + dy * tfm[3])
    canonicalize_spaceship dualPattern, rule, dx1, dy1

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
