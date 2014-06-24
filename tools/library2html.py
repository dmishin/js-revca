#!/usr/bin/env python

from xml.etree.ElementTree import ElementTree, Element, SubElement, Comment, tostring
from optparse import OptionParser
import sys
import json

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

"""
def Getter(path):
    parts = path.split('/')
    def get(record):
        elem = record
        for part in parts:
            if elem is None: return None
            elem = elem.get(part)
"""        

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
if __name__=="__main__":
    parser = OptionParser(usage = "%prog [options] library.json\nConvert library to html file")

    (options, args) = parser.parse_args()
    
    if len(args) < 1:
        parser.error("JSON code not specified")
    elif len(args)> 1:
        parser.error("Too many arguemnts")
    else:
        infile = args[0]


    with open(infile,'r') as hfile:
        data = json.load(hfile)

    data.sort( key = lambda r: (len(r['result']['cells']), r['result']['period']))

    totalCount = total(data)

    parameters = [
        Parameter('RLE', lambda r: r['key']),
        Parameter('Size', lambda r: len(r['result']['cells'])),
        Parameter('Period', lambda r: r['result']['period']),
        Parameter('dx', lambda r: r['result']['dx']),
        Parameter('dy', lambda r: r['result']['dy']),
        Parameter('Velocity', (lambda r: rational2str(max(r['result']['dx'], r['result']['dy']), r['result']['period']))),
        Parameter('Velocity', (lambda r: '%0.3g'%(max(r['result']['dx'], r['result']['dy']) / r['result']['period']))),
        Parameter('Type', lambda r: gliderType(r['result']['dx'], r['result']['dy'])),
        Parameter('Count', lambda r: r['count']),
        Parameter('Probability', lambda r: '%0.3g'%(r['count'] / totalCount) )
    ]        
    

    print('<html><body>')
    print('<table><thead><tr>')
    for param in parameters:
        print (param.header())
    
    print('</tr></thead>')
    print('<tbody>')

    for record in data:
        print ('<tr>')
        print (''.join(param.value(record) for param in parameters))
        print ('</tr>')
    print('</tbody>')
    print('</table>')

    print('</body></html>')
