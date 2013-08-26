assert = require "assert"
math_util = require "../scripts-src/math_util"

# mocha tests/test-math-utils.coffee --compilers coffee:coffee-script

describe "mod(num, den)", ->
  {mod} = math_util
  it "should work the same as % when numerator is nonneg", ->
    assert.equal mod(1, 2), 1
    assert.equal mod(1, 3), 1
    assert.equal mod(0, 3), 0
    assert.equal mod(5, 3), 2
    assert.equal mod(21, 7), 0
  it "should return nonnegative value, when numerator is negative", ->
    assert.equal mod(-1,2), 1
    assert.equal mod( -5, 3), 1
    assert.equal mod(-21, 7), 0


describe "div(num,den)", ->
  {div} = math_util
  it "shold round down for positives", ->
    assert.equal div(0,2), 0
    assert.equal div(1,2), 0
    assert.equal div(5,2), 2
  it "shold round up for negatives", ->
    assert.equal div(-1,2), 0
    assert.equal div(-5, 2), -2

describe "getReadableFileSizeString(size)", ->
  grfs = math_util.getReadableFileSizeString
  it "should convert less that 1 mb to kbytes", ->
    assert.equal (grfs 512), "0.5 kB"
    assert.equal (grfs 1024), "1.0 kB"
    assert.equal (grfs 5*1024), "5.0 kB"
  it "should not return less than 0.1 kB", ->
    assert.equal (grfs 1), "0.1 kB"
  it "should work with megabytes", ->
    assert.equal (grfs 1024*1024*5), "5.0 MB"
  it "should work with gigabytes", ->
    assert.equal (grfs 1024*1024*1024*5), "5.0 GB"


describe "rational2str(num, den)", ->
  r2s = math_util.rational2str
  it "should work in simple cases", ->
    assert.equal r2s(1,2), "1/2"
    assert.equal r2s(2,3), "2/3"
    assert.equal r2s(5,2), "5/2"
  it "should work with negatives", ->
    assert.equal r2s(-1,2), "-1/2"
    assert.equal r2s(1,-2), "-1/2"
    assert.equal r2s(-1,-2), "1/2"

  it "should reduce common denominator", ->
    assert.equal r2s(2,4), "1/2"
    assert.equal r2s(12,28), "3/7"

  it "should reduce common denominator in negative case too", ->
    assert.equal r2s(2,-4), "-1/2"
    assert.equal r2s(12,-28), "-3/7"
    assert.equal r2s(-12,28), "-3/7"

  it "should work with zeros", ->
    assert.equal r2s(0,1), "0"
    assert.equal r2s(0,2), "0"
    assert.equal r2s(0,-1), "0"
    
  it "should work with infinites", ->
    assert.equal r2s(1,0), "1/0"
    assert.equal r2s(2,0), "1/0"


describe "isign(x)", ->
  isign = math_util.isign
  it "should just work", ->
    assert.equal isign(0), 0
    assert.equal isign(-1), -1
    assert.equal isign(-10), -1
    assert.equal isign(1), 1
    assert.equal isign(100), 1


describe "fill_array(arr, n, x)", ->
  fill_array = math_util.fill_array
  it "should fill and extend regular arrays inplace, returning the same array", ->
    a = []
    retval = fill_array a, 4, "x"
    assert.deepEqual a, ["x", "x", "x", "x"]
    assert.deepEqual retval, ["x", "x", "x", "x"]

  it "should fill non-empty arrays too", ->
    a = [1,2,3]
    fill_array a, 3, 5
    assert.deepEqual a, [5,5,5]

describe "gcd(a,b)", ->
  gcd = math_util.gcd
  it "should work if a > b", ->
    assert.equal gcd(5,1), 1
    assert.equal gcd(5,2), 1
    assert.equal gcd(5,3), 1
    assert.equal gcd(14,12), 2
    assert.equal gcd(140,120), 20
    
  it "should work if a == b", ->
    assert.equal gcd(1,1), 1
    assert.equal gcd(5,5), 5
    assert.equal gcd(12,12), 12
  it "should work if a < b", ->
    assert.equal gcd(1,5), 1
    assert.equal gcd(2,5), 1
    assert.equal gcd(3,5), 1
    assert.equal gcd(120,140), 20

 describe "class Maximizer", ->
  {Maximizer} = math_util
  it "should incrementally search for a maximal value", ->
    m = new Maximizer
    assert (not m.hasAny())
    m.put 1
    m.put -1
    m.put 10
    m.put 2
    assert m.hasAny()
    assert.equal m.getVal(), 10
    assert.equal m.getArg(), 10
  it "should support arrays", ->
    m = new Maximizer
    m.putAll [1, -1, 10, 2, 5]
    assert.equal m.getVal(), 10
    assert.equal m.getArg(), 10
  it "should support key functions", ->
    m = new Maximizer((x)->-x)
    m.putAll [1, -1, 10, 2, 5]
    assert.equal m.getVal(), 1
    assert.equal m.getArg(), -1
  it "should raise exception, when not ready", ->
    m = new Maximizer
    assert.throws -> m.getVal()
    assert.throws -> m.getArg()    