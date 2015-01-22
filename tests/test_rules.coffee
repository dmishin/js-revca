assert = require "assert"
#module_cells = require "../scripts-src/cells"
#{Cells, evaluateCellList, evaluateLabelledCellList, splitFigure} = module_cells
module_rules = require "../scripts-src/rules"
{xor_transposition, compose_transpositions, Rule, from_list, from_list_elem, parse, Bits, parseElementaryCycleNotation
 NamedRules, randomElemRule} = module_rules
{Array2d, MargolusNeighborehoodField} = require "../scripts-src/reversible_ca"


describe "from_list_elem, to_list", ->
  it "must restore the same list",->
    rul = [0..15]
    rul1 = from_list_elem(rul).to_list()
    assert.deepEqual rul, rul1

describe "ElementaryRule.equals", ->
  rules = [
    from_list_elem([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]),
    from_list_elem([2,1,3,4,5,6,7,8,9,10,11,12,13,14,15,0]),
    from_list_elem([2,1,3,4,6,5,7,8,9,10,11,12,13,14,15,0])]
    
  it "must return true when comparing equal rules", ->
    for i in [0..2]
      assert.ok rules[i].equals rules[i]
      
  it "must return false when comparing equal rules", ->
    for i in [0..2]
      for j in [0..2]
        if i isnt j
          assert.ok not rules[i].equals rules[j]
          
describe "ElementaryRule.negated", ->
  it "must return negated rule", ->
    rule = from_list_elem [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]
    nrule = from_list_elem [14,13,12,11,10,9,8,7,6,5,4,3,2,1,0,15]
    assert.deepEqual rule.negated(), nrule
    
describe "ElementaryRule.reverse", ->
  it "must leave identity rule unchanged", ->
    id_rule = from_list_elem [0..15]
    assert.ok id_rule.equals id_rule.reverse()
    
  it "must revert shift-by-q rule", ->
    rule =  from_list_elem [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]
    irule = from_list_elem [15,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14]
    assert.ok rule.reverse().equals irule
    assert.ok irule.reverse().equals rule
    
  it "must return the same rule after double application", ->
    rule = from_list_elem [0,4,1,12,8,10,6,14, 2,9,5,13,3,11,7,15]
    assert.ok not rule.equals rule.reverse()
    assert.ok rule.equals rule.reverse().reverse()

  it "must raise exception if rule is not invertible", ->
    rule = from_list_elem [0,1,1,3,4,5,6,7,8,9,10,11,12,13,14,15]
    assert.throws -> rule.reverse()

describe "ElementaryRule.is_invertible", ->
  it "must return true for invertible rules", ->
    rule = from_list_elem [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]
    assert.ok rule.is_invertible()
  it "must return false for non-invertible rules", ->
    rule = from_list_elem [1,2,3,4,5,6,7,8,1,10,11,12,13,14,15,0]
    assert.ok not rule.is_invertible()

describe "ElementaryRule.invariance_type", ->
  it "must return 'const' for identity rule", ->
    assert.equal "const", from_list_elem([0..15]).invariance_type()
  it "must return 'const' for the rotation rule", ->
    rule = from_list_elem [0,2,8,12,1,10,9, 11,4,6,5,14,3,7,13,15]
    assert.equal "const", rule.invariance_type()
  it "must return 'inv-const' for the Critters", ->
    rule = NamedRules.critters
    assert.equal "inv-const", rule.invariance_type()    
  it "must return 'none' for the chaotic rule", ->
    rule = from_list_elem [1,2,3,4,5,6,7,8,9,10,11,12,13,14,0,15]
    assert.equal "none", rule.invariance_type()

describe "parse(str, separator)", ->
  it "must parse with comma by default", ->
    s = "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0"
    r = parse s
    assert.deepEqual r.to_list(), [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]]

  it "must ignore whitespace and leading zeros", ->
    s = " 01,  02,\t3,4,5,6,7,8,9,   10\n,011,12,13,14,15,0"
    r = parse s
    assert.deepEqual r.to_list(), [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]]
    
  it "must raise an exception when rule is not complete", ->
    s = "1,2,3"
    assert.throws -> parse s
  it "must parse rulesets", ->
    s = "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0;2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1"
    r = parse s
    assert.deepEqual r.to_list(), [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0],[2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1]]

  
describe "compose_transpositions(t1, t2)", ->
  iden = [0..15]
  shift = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0]
  shift2 = [2,3,4,5,6,7,8,9,10,11,12,13,14,15,0,1]
  reverse = [15..0]
  it "must work with identity transposition", ->
    assert.deepEqual (compose_transpositions iden, iden), iden, "iden x iden"
    assert.deepEqual (compose_transpositions iden, shift), shift, "iden x shift"
    assert.deepEqual (compose_transpositions shift, iden), shift, "shift x iden"
  it "must work with shift-by-1 transformation", ->
    assert.deepEqual (compose_transpositions shift, shift), shift2
  it "must give identity for squared order-reverseion transposition", ->
    assert.deepEqual (compose_transpositions reverse, reverse), iden
  it "applies transpositions in argument order: first t1 then t2", ->
    # 1 -> 2; 2 -> 1
    t1 = [0,2,1,3,4,5,6,7,8,9,10,11,12,13,14,15]
    # 2 -> 3; 3 -> 2
    t2 = [0,1,3,2,4,5,6,7,8,9,10,11,12,13,14,15]

    # 1 -> 3; 2 -> 1; 3 -> 2
    t12 = [0,3,1,2,4,5,6,7,8,9,10,11,12,13,14,15]
    # 1 -> 2; 2 -> 3; 3 -> 1
    t21 = [0,2,3,1,4,5,6,7,8,9,10,11,12,13,14,15]
    assert.deepEqual (compose_transpositions t1, t2), t12
    assert.deepEqual (compose_transpositions t2, t1), t21
    
 describe "xor_transposition(x)", ->
  iden = [0..15]
  it "must return identity for XOR-ing with zero", ->
    assert.deepEqual xor_transposition(0), iden
  it "must transpose odd with even for x=1", ->
    assert.deepEqual xor_transposition(1), [1,0,3,2,5,4,7,6,9,8,11,10,13,12,15,14]
    
  it "compose xort(x1), xort(x2) === xort( x1 ^ x2 )", ->
    test = (x1,x2) ->
      assert.deepEqual compose_transpositions(xor_transposition(x1), xor_transposition(x2)), xor_transposition(x1 ^ x2)
    test 0, 0
    test 5, 7
    test 7, 5
    test 13, 15
    test 4, 9
    
describe "Rule.stabilize_vacuum(r)", ->
  it "must return rule itself, when vacuum is stable", ->
    iden_rule = parse "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15"    
    assert.deepEqual iden_rule.stabilize_vacuum(), iden_rule

    singlerot = from_list [[0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]]
    assert.deepEqual singlerot. stabilize_vacuum(), singlerot
    
  it "must return pair of rule and negated rule, when vacuum is not stable", ->
    critters = from_list [[15,14,13,3,11,5,6,1,7,9,10,2,12,4,8,0]]
    stab_critters = critters.stabilize_vacuum()
    assert.equal stab_critters.size(), 2
    [cr1, cr2] = stab_critters.rules
    assert.equal cr1.table[0], 0
    assert.equal cr2.table[0], 0
    
  it "must produce rule sequence that gives the same result as applying orignal rule several times", ->
    rule = from_list_elem [1,2,3,4,5,6,7,8,9,10,11,12,13,14,0,15]
    cells1 = new Array2d 64, 64
    field1 = new MargolusNeighborehoodField cells1
    cells2 = new Array2d 64, 64
    
    ide_rule = from_list_elem [0..15]
    field2 = new MargolusNeighborehoodField cells2
    
    cells1.set 32,32,1
    cells2.set 32,32,1

    stabilized = (new Rule(rule)).stabilize_vacuum()
    for iterator in [0...10]
      for stab_rule in stabilized.rules
        field1.transform rule
        field2.transform stab_rule
    assert.deepEqual cells1, cells2

describe "Rule.vacuum_period", ->
  it "must return 1 for identity rule", ->
    assert.equal 1, from_list([[0..15]]).vacuum_period()
  it "must return 1 for single rotation", ->
    assert.equal 1, NamedRules.singleRotate.vacuum_period()
  it "must return 2 for critters", ->
    assert.equal 2, NamedRules.critters.vacuum_period()
    
describe "Rule.vacuum_cycle(rule)", ->
  it "must return [0] for stable vacuum rules", ->
    iden_rule = parse "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15"
    
    assert.deepEqual iden_rule.vacuum_cycle(), [0]

    singlerot = from_list [[0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]]
    assert.deepEqual singlerot.vacuum_cycle(), [0]

  it "must return [0,15] for 'flashing' rules", ->
    critters = from_list [[15,14,13,3,11,5,6,1,7,9,10,2,12,4,8,0]]
    assert.deepEqual critters.vacuum_cycle(), [0,15]

  it "must return correct result for complex asymmetric rule", ->
    rule = from_list [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,0,15]]
    cycle = rule.vacuum_cycle()
    assert.deepEqual cycle, [0,8,9,5,6,14]


describe "rules.parseElementaryCycleNotation(str)", ->
  it "must correctly parse empty string", ->
    assert.deepEqual parseElementaryCycleNotation(""), from_list_elem([0..15])
  it "must parse nontrivial case (single rot)", ->
    srot = from_list_elem [0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15]
    assert.deepEqual parseElementaryCycleNotation("(1,2,8,4)"), srot
    
  it "must parse nontrivial case (double rot)", ->
    dblRot = from_list_elem [0,2,8,3,1,5,6,13,4,9,10,7,12,14,11,15]
    assert.deepEqual parseElementaryCycleNotation("(1,2,8,4)(14,11,7,13)"), dblRot
    

describe "randomElemRule", ->
  iden = from_list_elem [0..15]
  
  it "must return some invertible rule", ->
    for i in [0...1000]
      r = randomElemRule()
      assert.ok r
      assert.ok r.is_invertible()
    
  it "must return non-identity rule at least once in 1000 tries", ->
    found = false
    for i in [0...1000]
      r = randomElemRule()
      if r.stringify() isnt iden.stringify()
        found = true
        break
    assert.ok found

    