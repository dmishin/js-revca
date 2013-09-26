# module rules
#Composition of two transpositions, given as arrays of the same size
# Returns list, representing transposition of the same size
compose_transpositions = (t1, t2) ->
  if (n=t1.length) isnt t2.length then throw new Error "Transpositions are incompatible"
  return (t2[t1_i] for t1_i in t1)
  
exports.Rules = Rules = 
  ###
  # Create rule object from list
  ###
  from_list: 
    if Int8Array?
      (rule_list) -> new Int8Array(rule_list)
    else
      (rule_list) -> rule_list
      
  to_list:
    if Int8Array?
      (tarr) -> (ti for ti in tarr)
    else
      (rule) -> rule
    
  ###
  # Parse string rule
  ###
  parse: (rule_str, separator = ",") ->
    parts = rule_str.split separator
    nparts = parts.length
    throw new Error "Invalid rule string [" + rule_str + "], rule must have 16 parts, but have " + nparts  unless nparts is 16
    rule = []
    for riStr, i in parts
      rule.push ri = parseInt(riStr, 10)
      throw "Invalid value [" + ri + "] at position " + i + " in rule; must have values in range 0..15"  unless 0 <= ri < 16
    Rules.from_list rule
   # Rule to string. Revers to parse.
  stringify: (rule) -> Rules.to_list(rule).join ","
  equals: (r1, r2) ->
    for r1i, i in r1
      return false if r1i isnt r2[i]
    true
  ###
  # Inverse rule, raise exception if impossible
  ###
  reverse: (rule) ->
    if not Rules.is_invertible rule then throw new Error "Rule is not invertible"
    
    rrule = (null for i in [0..15])  
    for i in [0..15]
      rrule[rule[i]] = i
     Rules.from_list rrule
  ###
  # Checks whether the rule is invertible
  ###
  is_invertible: (rule) ->
    r = (ri for ri in rule) #make a copy, because sorting is inplace
    r.sort((a,b)->a-b)
    for ri, i in r
      if ri isnt i
        return false
    true
    
  make_from_samples: (samples, invariants) ->
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
    Rules.from_list rule
    
  ###
  #Take samples, pairs ( (a,b)... ) and builds rotation-invariant function,
  #that supports this transformation
  ###
 
  make_rot_invariant_rule_from_samples: (samples) ->
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
    Rules.from_list rule
    
  ###
  (rule::Rule, transform::Int->Int).
  Checks, if  Rule*Transform == Transofmr*Rule
  ###
  is_transposable_with: (rule, transform) ->
    for x in [0 ... 16]
      x_t_f = rule[transform(x)]
      x_f_t = transform(rule[x])
      return false  unless x_t_f is x_f_t
    true
    
  find_symmetries: (rule) ->
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
      if Rules.is_transposable_with(rule, transform)
        symmetries[name] = true
    symmetries
  ###
  #Rules can be:
  #- Stable: population never changes
  #- Inverse-stable: population inverts on every step
  #- None: population changes.
  ###
  invariance_type: (rule) ->
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
  vacuum_period: (rule) ->
    # abab  ....
    # cdcd  .dc.
    # abab  .ba.
    # cdcd  ....
    mirror_bits = Bits.rotate180
    x = 0
    for period in [1..16] #Period can't be more than 16 or less than 1
      if (x = mirror_bits rule[x]) is 0
        return period
    null
  #Convert a "flashing" rule, that inverses vacuum on each steps, into 2 vacuum-preserving rules.
  # Applying these 2 rules will give the same result as applying original rule twice
  flashing_to_regular: (rule)->
    if not Rules.is_flashing rule then throw new Error "Rule is not flashing"
    transp_inv = Bits.tabulate Bits.invert
    [ compose_transpositions(rule, transp_inv),
      compose_transpositions(transp_inv, rule) ]
      
  #Flashing rule is a rule that converts vacuum to its inverse and back, on each step
  is_flashing: (rule) -> rule[0] is 15
  #Vaccum-stable rules don't change empty field
  is_vacuum_stable: (rule) -> rule[0] is 0
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
  tron: Rules.parse "15,1,2,3,4,5,6,7,8,9,10,11,12,13,14,0", ","
  billiardBallMachine: Rules.parse "0,8,4,3,2,5,9,7,1,6,10,11,12,13,14,15"
  bounceGas: Rules.parse "0,8,4,3,2,5,9,14, 1,6,10,13,12,11,7,15"
  hppGas: Rules.parse "0,8,4,12,2,10,9, 14,1,6,5,13,3,11,7,15"
  rotations: Rules.parse "0,2,8,12,1,10,9, 11,4,6,5,14,3,7,13,15"
  rotations2: Rules.parse "0,2,8,12,1,10,9, 13,4,6,5,7,3,14,11,15"
  rotations3: Rules.parse "0,4,1,10,8,3,9,11, 2,6,12,14,5,7,13,15"
  rotations4: Rules.parse "0,4,1,12,8,10,6,14, 2,9,5,13,3,11,7,15"
  sand: Rules.parse "0,4,8,12,4,12,12,13, 8,12,12,14,12,13,14,15"
  stringThing: Rules.parse "0,1,2,12,4,10,9,7,8, 6,5,11,3,13,14,15", ","
  stringThing2: Rules.parse "0,1,2,12,4,10,6,7,8, 9,5,11,3,13,14,15"
  swapOnDiag: Rules.parse "0,8,4,12,2,10,6,14, 1,9,5,13,3,11,7,15"
  critters: Rules.make_rot_invariant_rule_from_samples [
      [0, 15], [15, 0], [1, 14], [14, 8], [3, 3], [6, 6]]
      
  doubleRotate: Rules.parse "0, 2, 8, 3, 1, 5, 6, 13, 4, 9, 10, 7, 12, 14, 11, 15"
  singleRotate: Rules.make_rot_invariant_rule_from_samples [
      [0, 0], [1, 2], [3, 3], [6, 6], [7, 7], [15, 15]]
                
exports.Rule2Name = (->
  r2n = {}
  for name, rule of NamedRules
    r2n[ Rules.stringify rule ] = name
  r2n
)()
    
