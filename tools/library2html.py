#!/usr/bin/env python
from xml.etree.ElementTree import ElementTree, Element, SubElement, Comment, tostring
from optparse import OptionParser
import sys
import json
import os
import rle2svg
import shutil

def gliderType(dx, dy):
  if dx == 0 and dy == 0:
    return "static"
  elif dx == 0 or dy == 0:
    return "orthogonal"
  elif abs(dx)==abs(dy):
    return "diagonal"
  else:
    return "slant"

def total(data):
    return sum(r['count'] for r in data)

class Parameter:
    def __init__(self, title, getter, header_class=None):
        self.title = title
        self.getter = getter
        self.header_class = header_class
    def header(self):
        if self.header_class:
            args = ' class="%s"'%(self.header_class)
        else:
            args = ''
        return "<th%s>%s</th>"%(args, self.title)
    def value(self, record):
        return '<td>%s</td>'%(self.getter(record))

def gcd(a,b):
    "Greatest common divisor"
    while True:                
        if b==0: return a
        if a%b==0: return b
        a,b = b,a%b

def rational2str(n,d):
    if n == 0 and d == 0: return '0/0'
    if d == 0: return 'inf'
    
    g = gcd(n,d)
    n /= g
    d /= g
    if d != 1:
        return '%d/%d'%(n,d)
    else:
        return str(n)


def imageMaker(folder, folderName):
    def getter(record):
        rle = record['key']
        name = rle+".svg"
        fname = os.path.join(folder, name)
        cells = record['result']['cells']
        def roundup(x): return x-(x%2)+2
        # 0 -> 2
        # 1 -> 2
        # 2 -> 4
        fs_x = roundup(max(c[0] for c in cells))
        fs_y = roundup(max(c[1] for c in cells))
        tree = rle2svg.CreateField(cells,fs_x,fs_y, 12)
        with open(fname, 'wb') as ofile:
            tree.write(ofile, encoding="utf-8", xml_declaration=True)
        return folderName + "/" + name
    return getter
        
if __name__=="__main__":
    parser = OptionParser(usage = "%prog [options] library.json\nConvert library to html file")
    parser.add_option("-o", "--output", dest="output", default=None,
                      help="write HTML to FILE, default is name of input", metavar="FILE")


    parser.add_option("-r", "--rule", dest="rule", default='0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15', 
                      help="Rule to reference in simulator, list of 16 integers. Defautl is single rotation.", metavar="RULE")

    (options, args) = parser.parse_args()
    
    
    if len(args) < 1:
        parser.error("JSON code not specified")
    elif len(args)> 1:
        parser.error("Too many arguemnts")
    else:
        infile = args[0]

    try:
      rule = [int(r.strip()) for r in options.rule.split(',')]
      if len(rule) != 16: raise ValueError("Rule must have 16 parts")
      srule = ",".join(map(str, rule))
    except Exception as err:
      parser.error("Failed to parse rule: %s"%err)

    rle2svg.cell_style = "fill:black;stroke:none"
    rle2svg.bg_style = "stroke:rgb(127,127,127);fill:rgb(240,240,240)"
    rle2svg.grid1_style = "stroke:rgb(160,160,160);stroke-width:1"
    rle2svg.grid2_style = "stroke:rgb(160,160,160);stroke-width:1;stroke-dasharray:1,2"


    ofileName = options.output
    if ofileName is None:
        ofileName = os.path.splitext(os.path.basename(infile))[0]  + '.html'
        

    with open(infile,'r') as hfile:
        data = json.load(hfile)

    data.sort( key = lambda r: (len(r['result']['cells']), r['result']['period']))

    totalCount = total(data)

    outdir = os.path.splitext(ofileName)[0]+"_files"
    if not os.path.exists(outdir):
        os.makedirs(outdir)
    outdirName = os.path.basename(outdir)

    baseUrl = "http://dmishin.github.io/js-revca/index.html?rule={rule}&rle_x0={x0}&rle_y0={y0}&step=8&frame_delay=10&size={width}x{height}&cell_size=4,1&rle={rle}"    
    def makeUrl(record):
      width = 64
      height = 64
      cells = record['result']['cells']
      rle = record['key']
      pwidth = max( c[0] for c in cells )+1
      pheight = max( c[1] for c in cells)+1
      dx = pwidth//4*2
      dy = pheight//4*2
      
      return baseUrl.format( rule=srule, x0 = width//4*2 - dx, y0 = height//4*2 - dy,
                             width = width, height=height, rle = rle )
      
      

    mkImage = imageMaker(outdir, outdirName)
    parameters = [
        Parameter('Image', lambda r: '<a target="_blank" href="%s" title="Try in the simulator"><img src="%s"/></a>'%(makeUrl(r), mkImage(r)), header_class='sorttable_nosort'),
        Parameter('RLE', lambda r: '<a target="_blank" href="%s" title="Try in the simulator">%s</a>'%(makeUrl(r), r['key'])),
        Parameter('Size', lambda r: len(r['result']['cells'])),
        Parameter('Period', lambda r: r['result']['period']),
        Parameter('&Delta;x', lambda r: r['result']['dx']),
        Parameter('&Delta;y', lambda r: r['result']['dy']),
        Parameter('Velocity', (lambda r: rational2str(max(r['result']['dx'], r['result']['dy']), r['result']['period'])), header_class='sorttable_nosort'),
        Parameter('Velocity value', (lambda r: '%0.3g'%(max(r['result']['dx'], r['result']['dy']) / r['result']['period'])), header_class='sorttable_numeric'),
        Parameter('Type', lambda r: gliderType(r['result']['dx'], r['result']['dy'])),
        Parameter('Count', lambda r: r['count']),
        Parameter('Probability', lambda r: '%0.3g'%(r['count'] / totalCount), header_class='sorttable_numeric' )
    ]        

    scriptPath = os.path.join(outdir, 'sorttable.js')
    scriptName = outdirName + "/" + 'sorttable.js'
    sourceScript = os.path.join(os.path.dirname(__file__), '../scripts-src/sorttable.js')
    shutil.copyfile(sourceScript, scriptPath)
    
    cssPath = os.path.join(outdir, 'style.css')
    cssName = outdir + '/' + 'style.css'
    cssSource = os.path.join(os.path.dirname(__file__), '../table.css')
    shutil.copyfile(cssSource, cssPath)
    
    with open(ofileName,'w') as ofile:

        ofile.write('<html>')
        ofile.write('<head><script src="%s"></script></head>'%(scriptName))
        ofile.write('<link rel="stylesheet" type="text/css" href="%s"/>'%(cssName))
        ofile.write('<body>')
        ofile.write('<p>Rule: [{rule:s}]. Different patterns: {patterns:d}. Total patterns collected: {total:d}.</p>'.format(
          rule=srule, patterns=len(data), total=totalCount
        ))
        ofile.write('<table class="sortable"><thead><tr>')
        for param in parameters:
            ofile.write (param.header())

        ofile.write('</tr></thead>')
        ofile.write('<tbody>')

        for record in data:
            ofile.write ('<tr>')
            ofile.write (''.join(param.value(record) for param in parameters))
            ofile.write ('</tr>')
        ofile.write('</tbody>')
        ofile.write('</table>')

        ofile.write('</body></html>')
