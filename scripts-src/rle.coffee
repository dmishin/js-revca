###
Library for RLE ensocing and decoding, used by Life programs
###
# Requires: nothing.
###
Encoder, creating RLE string from cell data
###
class RLEEncoder
  constructor: ->
    @stack = []
    @cur_item = null

  get_cur_char: ->
    ci = @cur_item
    unless ci?
      null
    else
      ci[0]

  put_cell: (value) -> @put (if value then "o" else "b")

  newline: -> @put "$"

  put: (c) ->
    throw "Character " + c + " is wrong"  unless c in ["b", "o", "$"]
    cur_char = @get_cur_char()
    if c is cur_char
      @cur_item[1] += 1
    else
      if c is "$" and cur_char is "b"
        @pop()
        @put c
      else
        @cur_item = [c, 1]
        @stack.push @cur_item

  pop: ->
    stk = @stack
    stk.pop()
    if stk.length is 0
      @cur_item = null
    else
      @cur_item = stk[stk.length - 1]

  trim_zeros: ->
    stk = @stack
    loop
      len = stk.length
      if len > 0
        c = stk[len - 1][0]
        if c is "$" or c is "b"
          stk.pop()
          continue
      break

  get_rle: ->
    @trim_zeros()
    output = ""
    for [c, cnt] in @stack
      if cnt > 1
        output += cnt
      output += c
    output


###
Parse Life RLE string, producing 2 arrays: Xs and Ys.
###
exports.parse_rle = (rle_string, put_cell) ->
  x = 0
  y = 0
  curCount = 0
  for i in [0 ... rle_string.length]
    c = rle_string.charAt(i)
    if "0" <= c <= "9"
      curCount = curCount * 10 + parseInt(c,10)
    else
      count = Math.max(curCount, 1)
      curCount = 0
      switch c
        when "b"
          x += count
        when "$"
          y += count
          x = 0
        when "o"
          for j in [0...count] by 1
            put_cell x, y
            x+=1
        else
          throw new Error "Unexpected character '#{c}' at position #{i}"
  null
  
exports.remove_whitespaces = remove_whitespaces = (s) -> s.replace /\s+/g, ""
