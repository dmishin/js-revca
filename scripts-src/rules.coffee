# module rules
#Composition of two transpositions, given as arrays of the same size
# Returns list, representing transposition of the same size
exports.compose_transpositions = compose_transpositions = (t1, t2) ->
  if (n=t1.length) isnt t2.length then throw new Error "Transpositions are incompatible"
  return (t2[t1_i] for t1_i in t1)

#Generates transposition, produced by XOR'ing given value with original value
exports.xor_transposition = xor_transposition = (x) ->
  unless 0<=x<=15
    throw Error "Argument must be between 0 and 15"
  (y ^ x for y in [0..15])


list2array =
  if Int8Array?
    (table) -> new Int8Array(table)
  else
    (table) -> table

exports.Rule = class Rule
  constructor: (table) ->
    @table = list2array table
    @validate()
    
  validate: ->
    if @table.length != 16
      throw new Error "Rule must have 16 components"
    for r in @table
      if r <0 or r > 15 or r != (r|0)
        throw new Error "Rule components must be integers i nthe range 0..15"
        
  to_list:
    if Int8Array?
      () -> (ti for ti in @table)
    else
      () -> @table
      
  toString: -> "Rule(["+@stringify()+"])";
  
  stringify: -> @to_list().join ","
  
  equals: (rule) ->
    table2 = rule.table
    for r1i, i in @table
      return false if r1i isnt table2[i]
    true
    
  ###
  # Inverse rule, raise exception if impossible
  ###
  reverse: ->
    if not @is_invertible() then throw new Error "Rule is not invertible"    
    rrule = (null for i in [0..15])  
    for i in [0..15]
      rrule[@table[i]] = i      
    new Rule rrule
        
  ###
  # Checks whether the rule is invertible
  ###
  is_invertible: ->
    r = (ri for ri in @table) #make a copy, because sorting is inplace
    r.sort((a,b)->a-b)
    for ri, i in r
      if ri isnt i
        return false
    true

  ###
  (rule::Rule, transform::Int->Int).
  Checks, if  Rule*Transform == Transofmr*Rule
  ###
  is_transposable_with: (transform) ->
    for x in [0 ... 16]
      x_t_f = @table[transform(x)]
      x_f_t = transform(@table[x])
      return false unless x_t_f is x_f_t
    true
    
  find_symmetries: ->
    fliph_negate = (x) -> Bits.negate Bits.flip_h x
    flipv_negate = (x) -> Bits.negate Bits.flip_v x
    transforms = [
      ["rot90", Bits.rotate],
      ["rot180", Bits.rotate180],
      ["flipx", Bits.flip_h],
      ["flipy", Bits.flip_v],
      ["negate", Bits.negate],
      ["flipy_neg", flipv_negate],
      ["flipx_neg", fliph_negate]
      ]
      
    symmetries = {}
    for [name, transform] in transforms
      if @is_transposable_with transform
        symmetries[name] = true
    symmetries
  ###
  #Rules can be:
  #- Stable: population never changes
  #- Inverse-stable: population inverts on every step
  #- None: population changes.
  ###
  invariance_type: ->
    rule = @table
    pop_stable = true
    pop_invstable = true
    for x in [0 ... 16]
      sx = Bits.sum x
      sy = Bits.sum rule[x]
      pop_stable = false  unless sx is sy
      pop_invstable = false  unless sx is 4 - sy
      break  if not pop_stable and not pop_invstable
    return "const"  if pop_stable
    return "inv-const"  if pop_invstable
    "none"
  
  #Calculate, in how many steps vacuum returns to the zero state.
  # If it never returns (could be a case in non-invertible rules),
  # return null
  vacuum_period: -> @vacuum_cycle().length
    
  #Evolution of empty field.
  # For rules with stable vacuum, returns [0]
  vacuum_cycle: ->
    # abab  ....
    # cdcd  .dc.
    # abab  .ba.
    # cdcd  ....
    mirror_bits = Bits.rotate180
    x = 0
    cycle = [x]
    for period in [1..16] #Period can't be more than 16 or less than 1
      if (x = mirror_bits @table[x]) is 0
        break
      cycle.push x
    cycle
    
  #Convert a "flashing" rule, that inverses vacuum on each steps, into 2 vacuum-preserving rules.
  # Applying these 2 rules will give the same result as applying original rule twice
  flashing_to_regular: ->
    if not @is_flashing() then throw new Error "Rule is not flashing"
    @stabilize_vacuum()

  #Convert a rule with unstable vacuum to a secuence of rules with stable vacuum
  #These rules represent evulution of difference between vacuum and pattern.
  stabilize_vacuum: ->
    cycle = @vacuum_cycle()
    # Assume vacuum cycle is : [0, V1, V2, V3]
    # Then rule maps 0 to V1', where ' is rotate-by-180 operation.
    #      (Bits.rotate180)
    #
    # Transpositions, that change vacuum to 0 on each corresponding step
    #console.log "cycle:" + JSON.stringify(cycle)
    stabilizers  = (xor_transposition(ci) for ci in cycle)
    stabilizersR = (xor_transposition(Bits.rotate180(ci)) for ci in cycle)
    
    period = cycle.length
    # Stabilized rules are:
    # r1 : XOR_V1( RUle (XOR_0 (x)))
    # r2 : XOR_V2( Rule (XOR_V1 (x)))
    # r3 : XOR_V3( Rule (XOR_V2 (x)))
    # r4 : XOR_0(  Rule (XOR_V3 (x)))
    compose3 = (t1,t2,t3) -> compose_transpositions( compose_transpositions( t1, t2), t3 )

    for i in [0...period] by 1
      i1 = (i+1)%period
      new Rule compose3( stabilizers[i], @table, stabilizersR[i1] )
      
  #Flashing rule is a rule that converts vacuum to its inverse and back, on each step
  # (vacuum cycle is [0,15])
  is_flashing:  -> (@table[0] is 15) and (@table[15] is 0)
  
  #Vaccum-stable rules don't change empty field
  # (vacuum cycle is [0])
  is_vacuum_stable: -> @table[0] is 0

    

###
# Create rule object from list
###
exports.from_list = from_list = (t) -> new Rule(t)
              
###
# Parse string rule
###
exports.parse = parse = (rule_str, separator = ",") ->
  parts = rule_str.split separator
  new Rule (parseInt(riStr, 10) for riStr in parts)
  # Rule to string. Revers to parse.
            
exports.make_from_samples = make_from_samples =(samples, invariants) ->
  all_transforms = (x, y, transforms)->
    x2y = (null for i in [0..15])
    xy_pairs = []
    #Walker that recursively finds all different transformations of x and corresponding transformations of y
    walk = (x,y) ->
      if (y_old = x2y[x])?
        if y_old isnt y
          throw new Error "Samples are contradicting invariants" 
      else
        x2y[x] = y
        xy_pairs.push [x,y]
        for tfm in transforms
          walk tfm(x), tfm(y)
      null
    walk x, y
    return xy_pairs
  ############
  rule = (null for i in [0..15])
  for [a0,b0], i in samples
    for a, b in all_transforms a, b, invariants
      if rule[a] isnt null and rule[a] isnt b
        throw new Error "Sample #{i + 1} conflicts with other samples"  
      rule[a] = b
  for ri, i in rule
    if ri is null
      throw new Error "Samples incomplete. State " + i + " has no descendant"  
  new Rule rule

###
#Take samples, pairs ( (a,b)... ) and builds rotation-invariant function,
#that supports this transformation
###
exports.make_rot_invariant_rule_from_samples = make_rot_invariant_rule_from_samples = (samples) ->
  rule = (null for i in [0..15])
  for [a,b], i in samples
    for r in [0..3]
      if rule[a] isnt null and rule[a] isnt b
        throw new Error "Sample #" + (i + 1) + " (rotated by" + r + ") conflicts"  
      rule[a] = b
      a = Bits.rotate a
      b = Bits.rotate b
  for ri, i in rule
    if ri is null
      throw new Error "Samples incomplete. State " + i + " has no descendant"  
  new Rule rule
  
  
#Operations over 4-bit blocks
exports.Bits = Bits = 
  ####
  # Rotate block of 4 bits counter-clockwise
  ####
  rotate: (x) ->
    [a,b,c,d] = Bits.get(x)
    # a b| -> |b d|
    # c d| -> |a c|
    Bits.fromBits b, d, a, c
  get: (x) -> ( (x >> i) & 1 for i in [0 .. 3] )
  fromBits: (a,b,c,d) -> a | (b << 1) | (c << 2) | (d << 3)
  rotate180: (x) ->
      [a,b,c,d] = Bits.get(x)
      # a b| -> |d c|
      # c d| -> |b a|
      Bits.fromBits d, c, b, a
   flip_h: (x) ->
      [a,b,c,d] = Bits.get(x)
      # |a b| -> |b a|
      # |c d| -> |d c|
      Bits.fromBits b, a, d, c
   flip_v: (x) ->
      [a,b,c,d] = Bits.get(x)
      # |a b| -> |c d|
      # |c d| -> |a b|
      Bits.fromBits c, d, a, b
   negate: (x) ->
      15 - x
   sum: (x) ->
    [a,b,c,d] = Bits.get(x)
    a + b + c + d
  tabulate: (func) -> (func(i) for i in [0..15])
  
 #Some rules from: http://psoup.math.wisc.edu/mcell/rullex_marg.html
exports.NamedRules = NamedRules = 
  tron: new Rule [15,1,2,3,4,5,6,7,8,9,10,11,12,13,14,0]
  billiardBallMachine: new Rule [0,8,4,3,2,5,9,7,1,6,10,11,12,13,14,15]
  bounceGas: new Rule [0,8,4,3,2,5,9,14, 1,6,10,13,12,11,7,15]
  hppGas: new Rule [0,8,4,12,2,10,9, 14,1,6,5,13,3,11,7,15]
  rotations: new Rule [0,2,8,12,1,10,9, 11,4,6,5,14,3,7,13,15]
  rotations2: new Rule [0,2,8,12,1,10,9, 13,4,6,5,7,3,14,11,15]
  rotations3: new Rule [0,4,1,10,8,3,9,11, 2,6,12,14,5,7,13,15]
  rotations4: new Rule [0,4,1,12,8,10,6,14, 2,9,5,13,3,11,7,15]
  sand: new Rule [0,4,8,12,4,12,12,13, 8,12,12,14,12,13,14,15]
  stringThing: new Rule [0,1,2,12,4,10,9,7,8, 6,5,11,3,13,14,15]
  stringThing2: new Rule [0,1,2,12,4,10,6,7,8, 9,5,11,3,13,14,15]
  swapOnDiag: new Rule [0,8,4,12,2,10,6,14, 1,9,5,13,3,11,7,15]
  critters: make_rot_invariant_rule_from_samples [
      [0, 15], [15, 0], [1, 14], [14, 8], [3, 3], [6, 6]]
      
  doubleRotate: new Rule [0, 2, 8, 3, 1, 5, 6, 13, 4, 9, 10, 7, 12, 14, 11, 15]
  singleRotate: make_rot_invariant_rule_from_samples [
      [0, 0], [1, 2], [3, 3], [6, 6], [7, 7], [15, 15]]
                
exports.Rule2Name = (->
  r2n = {}
  for name, rule of NamedRules
    r2n[ rule.stringify() ] = name
  r2n
)()
    
