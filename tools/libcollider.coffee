"use strict"
{Cells, inverseTfm} = require "../scripts-src/cells"
{evaluateCellList} = require "../scripts-src/analyser"
{mod,mod2} = require "../scripts-src/math_util"

### Implementation of the collider code
###
#
#

#put the pattern to the specified time and position, and return its state at time t
exports.patternAt = (rule, pattern, posAndTime, t) ->
  pattern = Cells.copy pattern
  [x0,y0,t0] = posAndTime
  Cells.offset pattern, x0, y0
  evalToTime rule, pattern, t0, t

exports.evalToTime = evalToTime = (rule, fld, t0, tend) ->
  if t > tend then throw new Error "assert: bad time"
  for t in [t0 ... tend] by 1
    fld = evaluateCellList rule, fld, mod2(t)
  return fld
