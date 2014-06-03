# module reversible_ca
  #array utilities
  exports.getReadableFileSizeString = (fileSizeInBytes) ->
    i = -1
    byteUnits = [" kB", " MB", " GB", " TB", "PB", "EB", "ZB", "YB"]
    loop
      fileSizeInBytes = fileSizeInBytes / 1024
      i++
      break unless fileSizeInBytes > 1024
    ""+Math.max(fileSizeInBytes, 0.1).toFixed(1) + byteUnits[i]

  exports.rational2str = rational2str = (num, den) ->
    if den < 0
      return rational2str -num, -den
    if num is 0
      if den is 0 then "0/0" else "0"
    else
      if den is 0 then "1/0"
      else
        d = gcd Math.abs(num), den
        "" + (num/d) + "/" + (den/d)

  ###
  Mathematical modulo (works with negative values)
  ###
  exports.mod = mod = (x, y) ->
    m = x % y
    (if (m < 0) then (m + y) else m)

  ###
  Integer division
  ###
  exports.div = (x, y) -> (x / y) | 0

  #mathematical [x/2]
  #for negative values, returns: div2(-1) = -1, div2(-2) = -1
  exports.div2 = (x) -> x >> 1
  #mathematical modulo 2
  exports.mod2 = (x) -> x & 1

  #integer sign.
  exports.isign = isign = (x) ->
    if x > 0
      1
    else if x < 0
      -1
    else
      0

  ###
  Fill 0-based array with constant value
  ###
  exports.fill_array = (arr, n, x) ->
    for i in [0...n]
      arr[i]=x
    arr

  scale_array_inplace = (arr, k) ->
    for i in [0...arr.length] by 1
      arr[i] *= k
    arr

  ###
  Primitive line drawing algorithm
  ###
  exports.line_pixels = line_pixels = (dx, dy) ->
    sx = isign dx
    sy = isign dy
    if sx < 0 or sy < 0
      [xx,yy] = line_pixels(dx * sx, dy * sy)
      scale_array_inplace xx, sx  unless sx is 1
      scale_array_inplace yy, sy  unless sy is 1
      return [xx,yy]
    if dy > dx
      [xx,yy] = line_pixels(dy, dx)
      return [yy, xx]
    return [[0], [0]] if dx is 0
    xx = []
    yy = []
    k = dy / dx
    for x in [0 .. dx]
      xx.push x
      yy.push Math.floor(x * k)
    [xx, yy]

  exports.gcd = gcd = (a,b)->
    if a < b
      gcd b, a
    else if b is 0
      a
    else
      gcd b, a%b
  #Limit value from top and bottom
  exports.cap = (a,b,x) -> Math.min b, Math.max a, x

  exports.Maximizer = class Maximizer
    constructor: (@targetFunc = (x)->x) ->
      @bestX = null
      @bestY = null
    put: (x) ->
      y = @targetFunc x
      if not @hasAny() or (y > @bestY)
        @bestX = x
        @bestY = y
      this
    putAll: (xs) ->
      for x in xs
        @put x
      null
    hasAny: () -> @bestY?
    getArg: () ->
      throw new Error "Has no values" unless @hasAny()
      @bestX
    getVal: () ->
      throw new Error "Has no values" unless @hasAny()
      @bestY
