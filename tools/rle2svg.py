#!/usr/bin/env python
from xml.etree.ElementTree import ElementTree, Element, SubElement, Comment, tostring
from optparse import OptionParser
from rle import parse_rle, rle2cell_list
import sys

cell_style = "fill:blue;stroke:black"
bg_style = "stroke:none;fill:rgb(240,255,255)"
grid1_style = "stroke:black;stroke-width:1"
grid2_style = "stroke:black;stroke-width:1;stroke-dasharray:2,4"

def CreateField(cells, cols, rows, cell_size = 20):


    svg = Element("svg", {
        "xmlns":"http://www.w3.org/2000/svg",
        "xmlns:xlink":"http://www.w3.org/1999/xlink",
        "width":"%dpx"%(cell_size*cols+1),
        "height":"%dpx"%(cell_size*rows+1),
        "viewBox":"0 0 %g %g"%(cell_size*cols+1, cell_size*rows+1)
    })


    defs = SubElement(svg, "defs")
    cell_image = SubElement(defs, "rect", {
        "id": "cell_image",
        "x":str(cell_size*0.15),
        "y":str(cell_size*0.15),
        "width": str(cell_size*0.7),
        "height": str(cell_size*0.7),
        "style": cell_style
    })

    background = SubElement(svg, "rect", {
        "x":"0", "y":"0",
        "width":"100%",
        "height":"100%",
        "style": bg_style
        })
    content = SubElement(svg, "g", {"transform":"translate(.5,.5)"})
    grids = SubElement(content, "g", {"id": "grids"})
    grid1 = SubElement(grids, "g", {"style":grid1_style})
    grid2 = SubElement(grids, "g", {"style":grid2_style})

    for row in range(rows+1):
        grid = [grid1,grid2][row%2]
        sy = str(row*cell_size)
        line = SubElement(grid, "line",{
            "x1": "0", "y1":sy,
            "x2": str(cols*cell_size), "y2":sy
        })

    for col in range(cols+1):
        grid = [grid1,grid2][col%2]
        sx = str(col*cell_size)
        line = SubElement(grid, "line",{
            "x1": sx, "y1":"0",
            "x2": sx, "y2":str(rows*cell_size)
        })

    cells_grp = SubElement(content, "g")
    for (x,y) in cells:
        xx = x * cell_size
        yy = y * cell_size
        cell = SubElement(cells_grp, "use",{
            "xlink:href": "#cell_image",
            "transform": "translate(%g %g)"%(xx,yy)})


    tree = ElementTree(svg)
    return tree

if __name__=="__main__":
    parser = OptionParser(usage = "%prog [options] RLE\nConvert RLE-encoded string to SVG field image.")

    parser.add_option("-o", "--output", dest="output",
                      help="write SVG to FILE", metavar="FILE")

    parser.add_option("-s", "--cell-size", dest="size", type="int", default=20,
                      help="Cell size")

    parser.add_option("-f", "--field_size", dest="field_size",
                      help="Size of the field, COLS:ROWS")
    parser.add_option("-x", "--put-at", dest="put_at",
                      help="put figure at position X:Y")

    (options, args) = parser.parse_args()
    
    if len(args) < 1:
        parser.error("RLE code not specified")
    elif len(args)> 1:
        parser.error("Too many arguemnts")
    else:
        rle = args[0]

    if options.size <= 0:
        parser.error("Cell size must be positive")
    
    if options.put_at:
        try:
            [x0,y0] = map(int, options.put_at.split(":"))
            if x0 % 2 or y0 % 2:
                print("Warrning: odd offset", file=sys.stderr)
        except Exception as e:
            parser.error("Failed to parse put-at parameter: %s"%(e))
    else:
        x0, y0 = 0,0


    cells = rle2cell_list(rle,x0,y0)

    xmax = max( x for (x,y) in cells ) + 1
    ymax = max( y for (x,y) in cells ) + 1
    xmax += xmax % 2
    ymax += ymax % 2
    
    
    if options.field_size:
        try:
            [fs_x, fs_y] = map(int, options.field_size.split(":"))
        except Exception as e:
            parser.error("Failed to parse field size: s"%(e))
        if fs_x % 2 or fs_y %2:
            print ("Warning: odd field size", file=sys.stderr)
        if xmax > fs_x or ymax > fs_y:
            print ("Warning: pattern out of the field", file=sys.stderr)            
    else:
        fs_x = xmax
        fs_y = ymax
            



    tree = CreateField(cells,fs_x,fs_y, options.size)
    def do_write(fl):
        tree.write(fl, encoding="utf-8", xml_declaration=True)

    if options.output:
        with open(options.output, "wb") as fl:
            do_write(fl)
    else:
        do_write(sys.stdout.buffer)
    



#convert to PNG:
# inkscape -f test.svg -e test.png
