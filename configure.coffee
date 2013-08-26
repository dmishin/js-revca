#!/usr/bin/env coffee
fs = require "fs"
path = require "path"

walkDir = (dir, cb) ->
  for fname in fs.readdirSync dir
    subPath = path.join dir, fname
    if fs.lstatSync(subPath).isDirectory()
      walkDir subPath, cb
    else
      cb dir, fname


js_sources = []
coffee_sources = []
js_outputs = []
coffee_outputs = []

makeCoffeeSource = (dir, fname)->
  ipath = path.join(dir, fname)
  odir = dir.replace(/^scripts-src/, "scripts")
  opath = path.join(odir, fname.replace(/.coffee$/,".js"))
  fs.writeSync makefile, "#{opath}: #{ipath}\n"
  fs.writeSync makefile, "\t$(COFFEE) $(COFFEE_FLAGS) -c -o #{odir} #{ipath}\n"
  coffee_sources.push ipath
  coffee_outputs.push opath
  
makeJsSource = (dir, fname)->
  ipath = path.join(dir, fname)
  odir = dir.replace(/^scripts-src/, "scripts")
  opath = path.join(odir, fname)
    
  fs.writeSync makefile, "#{opath}: #{ipath}\n"
  fs.writeSync makefile, "\tln -f #{ipath} #{opath}\n"
  js_sources.push ipath
  js_outputs.push opath



makefile = fs.openSync "Makefile", "w"

makefile_template = fs.readFileSync "Makefile.in"
fs.writeSync makefile, ""+makefile_template

walkDir "scripts-src", (d, f)->
  if /.coffee$/.test f
    makeCoffeeSource d, f
    
  else if /.js$/.test f
    makeJsSource d, f

joinStrings = (strs) -> strs.join " "

fs.writeSync makefile, "JS_SOURCES = #{joinStrings js_sources}\n"
fs.writeSync makefile, "COFFEE_SOURCES = #{joinStrings coffee_sources}\n"

fs.writeSync makefile, "JS_OUTPUTS = #{joinStrings js_outputs}\n"
fs.writeSync makefile, "COFFEE_OUTPUTS = #{joinStrings coffee_outputs}\n"
fs.writeSync makefile, "ALL_OUTPUTS = $(JS_OUTPUTS) $(COFFEE_OUTPUTS)\n"

fs.writeSync makefile, "everything: $(ALL_OUTPUTS)\n"
        
fs.closeSync makefile
