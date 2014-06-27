#!/usr/bin/env coffee

fs = require "fs"
jss = require "JSONStream"
stdio = require "stdio"

opts = stdio.getopt {
    #'rule': {key: 'r', args: 1, mandatory:true, description: "Reversible cellular automata rule, required for normalization. Format: 16 comma-separated decimals."}
    }, "output file"
  

unless opts.args?
    process.stderr.write "Output file not specified\n"
    process.exit 1



console.log "Processing file #{opts.args[0]}"
stream = fs.createReadStream opts.args[0]
parser = jss.parse()

stream.pipe parser

parser.on 'root', (obj) ->
  console.log obj.period
