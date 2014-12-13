"""     Create 2 big RLE files from the library,
     one for diagonal and one for orthogonal spaceships.
     
     Arrange them in a square pattern, generate 2-state RLE.

     usage:
      library2rle library.json --ospacing=10 --dspacing=20 
"""

from __future__ import print_function, division
import sys
from optparse import OptionParser
from rle import to_rle
import itertools
import os.path
import json
import math

def main():
    parser = OptionParser(usage = """%prog [options] library.json VX VY
Create big RLE file from the library, 
VX, VY are movement direction. 1 0 for orthogonal, 1 1 for diagonal.

Arrange them in a square pattern, generate 2-state RLE.""")

    parser.add_option("-o", "--output", dest="output",
                      help="Name of the output file to store diagram, defaiult is library-dx-dy.rle", metavar="FILE.rle")

    parser.add_option("-N", "--num-spaceships", dest="num_spaceships",
                      type="int", default=0,
                      help="How many spaceships to put. 0 is all (default)")

    parser.add_option("-C", "--columns", dest="columns", 
                      type="int", default=0,
                      help="How many oclumns to use, default is to make diagram square")

    parser.add_option("-S", "--spacing", dest="spacing", 
                      type="int", default=15,
                      help="Spacing between spaceships")
    
    (options, args) = parser.parse_args()
    
    if len(args) < 3:
        parser.error("Required arguments are: imput file, DX, DY")
    elif len(args) > 3:
        parser.error("Too many arguments")
    else:
        ifile, sdx, sdy = args
        try:
            dx, dy = map(int, (sdx, sdy))
        except ValueError as err:
            parser.error(str(err))
    if options.spacing %2 != 0:
        parser.error("spacing must be even")

    basename = os.path.splitext(os.path.basename(ifile))[0]
    ofile = options.output or "%s-%d-%d.rle"%(basename, dx, dy)
    

    #read data
    with open(ifile,'r') as hifile:
        data = json.load(hifile)

    #sort data by velocity
    def velocity(r):
        try:
            d = max(abs(r['result']['dx']), abs(r['result']['dy']))
            return d / r['result']['period']
        except KeyError:
            return 0
    data = sorted( data, key=velocity, reverse=True )
    
    #extract spaceships
    spaceships = extract_ss_by_direction( data, dx, dy )
    if options.num_spaceships > 0:
        spaceships = itertools.islice( spaceships, options.num_spaceships )
    spaceships = list(spaceships)
    
    num_spacenships = len(spaceships) #may be lesser than value in options
    if num_spacenships == 0:
        print ("Error! 0 spaceships with direction (%d %d) found"%(dx, dy), file=sys.stderr)
    #determine columns and rows
    if options.columns == 0:
        ncols = int(math.ceil(math.sqrt(num_spacenships)))
    else:
        ncols = options.columns
    #now number of rows
    nrows = int(math.ceil(num_spacenships / ncols ))

    #Now generate the pattern
    pattern = grid_pattern( spaceships, nrows, ncols, dx, dy, options.spacing )

    #And convert it to RLE

    pattern.sort(key = lambda (x,y): (y,x) )
    with open( ofile, "w") as hofile:
        hofile.write( to_rle( pattern ) )
    
    #print pattern
    
def grid_pattern( spaceships, nrows, ncols, dx, dy, spacing ):
    def translated( p, dx, dy ):
        return [[x+dx, y+dy] for x,y in p]
    
    rowdx, rowdy = -dy, dx

    def grid():
        for row in range(nrows):
            for col in range(ncols-1, 0, -1):
                yield ((row*rowdx + col*dx)*spacing,
                       (row*rowdy + col*dy)*spacing)
    pattern = []
    for ss, (tx, ty) in zip(spaceships, grid()):
        pattern.extend( translated( ss, tx, ty ))
    return pattern

def same_direction(v1, v2):
    def dot(a,b):
        return sum(ai*bi for ai,bi in zip(a,b))

    n1 = dot(v1, v1)
    n2 = dot(v2, v2)
    if (n1 == 0) or (n2 == 0):
        return (n1 == 0) and (n2 == 0)
    else:
        return n1*n2 == dot(v1,v2)**2
        
    

def extract_ss_by_direction( library, dx, dy ):
    for r in library:
        try:
            rdx = r['result']['dx']
            rdy = r['result']['dy']
        except KeyError: continue

        #rdx/rdy == dx/dy
        #rdx*dy == rdy*dx
        if same_direction( (rdx, rdy), (dx, dy)):
            yield r['result']['cells']
        

if __name__=="__main__":
    main()
