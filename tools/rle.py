def parse_rle(rle_string, put_cell):
    """based on the CoffeScript code"""
    x = 0
    y = 0
    curCount = 0
    for i in range(0, len(rle_string)):
        c = rle_string[i]
        if "0" <= c and c <= "9":
            curCount = curCount * 10 + int(c)
        else:
            count = max(curCount, 1)
            curCount = 0
            if c == "b":
                x += count
            elif c == "$":
                y += count
                x = 0
            elif c == "o":
                for j in range(0,count):
                    put_cell(x, y)
                    x+=1
            else:
                raise ValueError( "Unexpected character '%s' at position %d"%(c, i))

def rle2cell_list(rle, dx=0, dy=0):
    cells = []
    parse_rle(rle, lambda x,y: cells.append((x+dx,y+dy)))
    return cells



def to_rle(cells):
    """COnvert sorted (by y) list of alive cells to RLE encoding"""
    x0, y0 = lower_bound(cells)
    cells = [(x-x0, y-y0) for (x,y) in cells]
    rle = [""]
    count = [0]
    
    def appendNumber(n, c):
        if n > 1:
            rle.append( str(n))
        rle.append(c)

    def endWritingBlock():
      if count[0] > 0:
        appendNumber(count[0], "o")
        count[0] = 0

    x = -1
    y = 0
 
    for i, (xi, yi) in enumerate(cells):
      dy = yi - y
      if dy < 0:
          raise ValueError( "Cell list are not sorted by Y"  )
      
      if dy > 0: #different row
        endWritingBlock()
        appendNumber( dy, "$")
        x = -1
        y = yi
      dx = xi - x
      if dx <= 0:
          raise ValueError( "Cell list is not sorted by X"  )
      if dx == 1:
        count[0] += 1 #continue current horizontal line
      elif dx > 1: #line broken
        endWritingBlock()
        appendNumber( dx - 1, "b")  #write whitespace before next block
        count[0] = 1 #and remember the current cell
      x = xi
    endWritingBlock()
    return "".join(rle)

def lower_bound(cells ):
    xmin = min( x for x,y in cells )
    ymin = min( y for x,y in cells )
    def even_floor(x):
        return x - (x%2)
    return (even_floor(xmin), even_floor(ymin))

            
