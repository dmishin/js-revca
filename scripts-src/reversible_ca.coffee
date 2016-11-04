# module reversible_ca
#requires math_util.js
#Import section: add support for node.js
math_util = require "./math_util"
{mod, mod2} = math_util
{xor_transposition, from_list_elem} = require "./rules"
  
###
A 2-dimensional array of bytes!, with row-first organization
###
exports.Array2d = class Array2d
  constructor: (@width, @height) ->
    @num_cells = @width * @height
    @data =
      try
        new Int8Array(@num_cells)
      catch e #Don't have support for typed arrays?
        []
        
  fill: (v) -> math_util.fill_array @data, @num_cells, v

  cell_index: (x, y) -> y * @width + x

  set: (x, y, v) ->  @data[@cell_index(x, y)] = v
  set_wrapped: (x, y, v) ->  @data[@cell_index(mod(x,@width),mod(y,@height))] = v

  get: (x, y) ->     @data[@cell_index(x, y)]

  toggle: (x, y) ->  @data[@cell_index(x, y)] ^= 1

  size: -> [@width, @height]

  get_wrapped: (x, y) ->
    @data[@cell_index(mod(x, @width), mod(y, @height))]
  
  ###
  #Random fill block with given percentage
  ###
  random_fill: (x0, y0, x1, y1, percent) ->
    data = @data
    for y in [y0 ... y1] by 1
      i = @cell_index(x0, y)
      for x in [x0 ... x1] by 1
        data[i] = (if (Math.random() <= percent) then 1 else 0)
        i++
    null

  fill_box: (x0, y0, x1, y1, value) ->
    data = @data
    for y in [y0 ... y1] by 1
      i = @cell_index(x0, y)
      for x in [x0 ... x1] by 1
        data[i] = value
        i++
    null

  fill_outside_box: (x0, y0, x1, y1, value) ->  
    w = @width
    h = @height
    @fill_box 0, 0, w, y0     #111111
    @fill_box 0,  y0, x0, y1  #2    3
    @fill_box x1, y0, w,  y1  #2    3
    @fill_box 0, y1, w, h     #444444
 
  ###
  Find minimal bounding box for the given block of the field
  ###
  bounding_box: (x0, y0, x1, y1) ->
    xmin = x1 - 1
    ymin = y1 - 1
    xmax = x0
    ymax = y0
    for y in [y0 ... y1] by 1
      for x in [x0 ... x1] by 1
        if @get(x, y) isnt 0
          xmin = Math.min(xmin, x)
          xmax = Math.max(xmax, x)
          ymin = Math.min(ymin, y)
          ymax = Math.max(ymax, y)
    if xmax < xmin or ymax < ymin
       [x0, y0, x0, y0]
    else
      [xmin, ymin, xmax + 1, ymax + 1]
  is_nonempty: (x0,y0,x1,y1) ->
    for y in [y0 ... y1] by 1
      for x in [x0 ... x1] by 1
        if @get(x, y) isnt 0
          return true
    false
    
  ###
  return list of coordinates of active cells. Coordinates are relativeto the origin of the box
  ###
  get_cells: (x0, y0, x1, y1) ->
    rval = []
    for y in [y0 ... y1] by 1
      for x in [x0 ... x1] by 1
        rval.push [x - x0, y - y0]  if @get_wrapped(x, y) isnt 0
    rval

  ###
  Put list of cells to the field
  ###
  put_cells: (lst, x=0, y=0, value=1) ->
    w = @width
    h = @height
    for [xx,yy] in lst
      @set mod(x + xx, w), mod(y + yy, h), value
    null

  #Returns list of cells in the given region
  pick_pattern_at: (x, y, x0, y0, erase=false, range = 4, max_size=null) -> #[(int,int)]
    self = this
    w = @width
    h = @height
    visited = {} #set of visited coordinates
    cells = []
    key = (x,y) -> ""+x+"#"+y
    is_visited = (x,y) -> visited.hasOwnProperty key x, y
    visit = (x,y) -> visited[ key x, y ] = true

    #return true, if max size reached.
    do_pick_at = (x,y)->
      wx = mod(x,w) #Wrapped coordinates
      wy = mod(y,h)
      if is_visited(wx,wy) or self.get(wx,wy) is 0
        return false
      visit wx, wy
      cells.push [x-x0,y-y0]
      if max_size and (cells.length >= max_size)
        return true
      if erase then self.set wx, wy, 0
      for dy in [-range..range] by 1
        y1 = y+dy
        for dx in [-range..range] by 1
          continue if dy is 0 and dx is 0
          if do_pick_at x+dx, y1
            return true
      return false
    do_pick_at x, y
    cells
    
###
A field with Margolus neighborehood
###
exports.MargolusNeighborehoodField = class MargolusNeighborehoodField
  constructor: (@field) ->
    throw "Field size must be even, not " + @field.width + "x" + @field.height  if @field.width % 2 isnt 0 or @field.height % 2 isnt 0
    @phase = 0

  #implementation of the transform. Does not changes phase.
  _transform: (rule) ->
    xy0 = @phase
    rule_table = rule.table
    field = @field
    data = field.data
    w = field.width
    h = field.height
    a = 0 #cell index
    for y in [xy0 ... h] by 2
      dy = (if (y + 1 < h) then w else (w * (1 - h)))
      a = y*w+xy0
      for x in [xy0 ... w] by 2
        dx = (if (x + 1 < w) then 1 else (1 - w))
        #Code was inlined to increase performance
        b=a + dx; c=a + dy; d=b + dy;
        X = data[a] | (data[b] << 1) | (data[c] << 2) | (data[d] << 3)
        Y = rule_table[X]
        unless Y is X
          data[a] = Y & 1
          data[b] = (Y >> 1) & 1
          data[c] = (Y >> 2) & 1
          data[d] = (Y >> 3) & 1
        a += 2
    return

  #Combine given value by XOR with each block of the current phase.
  apply_xor: (value) -> @_transform from_list_elem xor_transposition value
    
  transform: (rule)->
    @_transform rule
    @phase ^= 1

  untransform: (irule) ->
    #it is important to switch phase *before* transforming, since we are going back in time. Order is reverse compared to `transform`.
    @phase ^= 1
    @_transform irule
    
  clear: ->
    @field.fill 0

  snap_below: (x) ->
    x - mod2(x + @phase)

  snap_upper: (x) ->
    x + mod2(x + @phase)

  snap_box: ([x0,y0,x1,y1]) ->
    [@snap_below(x0), @snap_below(y0), @snap_upper(x1), @snap_upper(y1)]
