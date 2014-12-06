#
# Library for RLE ensocing and decoding, used by Life programs
#
# Parse Life RLE string, producing 2 arrays: Xs and Ys.
#

exports.parse_rle = (rle_string, put_cell) ->
  x = 0
  y = 0
  curCount = 0
  for i in [0 ... rle_string.length]
    c = rle_string.charAt i
    if "0" <= c <= "9"
      curCount = curCount * 10 + parseInt(c,10)
    else if c in [" ", "\n", "\r", "\t"]
      continue
    else if c is "!"
      return
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
  return
  
exports.remove_whitespaces = remove_whitespaces = (s) -> s.replace /\s+/g, ""

exports.to_rle = to_rle = (cells) ->
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