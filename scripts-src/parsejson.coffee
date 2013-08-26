fs = require "fs"
revca = require "../scripts-src/reversible_ca"
cells = require "../scripts-src/cells"
rules = require "../scripts-src/rules"
#process = require "process"
#infile = "C:\\dmishin\\Dropbox\\Math\\rev-ca\\report3.json"
rule = rules.NamedRules.rotational1
{Cells, evaluateCellList, evaluateLabelledCellList} = cells

mergeReport = (report_file, key2record) ->
  data = JSON.parse fs.readFileSync report_file
  for record in data
    {result, count, key} = record
    rec = key2record[key]
    if rec?
      rec.count += count
    else
      key2record[key] = record

consolidateReports = (reports) ->
  key2record = {}
  for report in reports
    mergeReport report, key2record
  (record for key, record of key2record)

filterComposites = (records, rule) ->
  filtered = []
  for rec in consolidated
    {result, count, key} = rec
    grps = cells.splitFigure rule, result.cells, result.period
    if grps.length == 1
      filtered.push rec
  filtered

makeDualGlider = (glider, dx, dy) ->
  #Create dual glider, which is mirrored and phase-shifted.
  #For the rotational-1 rule, this dual glider is also a figure, that evolutes in reverse direction.

  g1 = Cells.transform (Cells.togglePhase glider), [-1, 0, 0, 1]
  dx1 = dx #phase shift reveses dx,dy; 
  dy1 = -dy #And mirror reverts only dx
  #Rotate glider to the right position
  [g1,dx1, dy1] = Cells.canonicalize_glider g1, rule, dx1, dy1
  if (dx1 isnt dx) or (dy1 isnt dy)
    throw new Error "New glider moves in the different direction, that's wrong for rotational rule"
  Cells.normalize g1

mergeDualGliders = (report) ->
  key2record = {}
  merged = 0
  for record in report
    {result, count, key} = record
    dual = makeDualGlider result.cells, result.dx, result.dy
    if key of key2record
      key2record[key].count += count #Duplicate entry?
      process.stderr.write "Duplicate entry: #{key}\n"
    else
      dual_key = Cells.to_rle dual
      if dual_key of key2record
        key2record[dual_key].count += count
        merged += 1
      else
        #Neither dual nor original are not registered yet
        key2record[key] = record
  process.stderr.write "Merged records: #{merged}\n"
  
  (record for key, record of key2record)

mergeNonUniqueNormalizations = (report, rule, mk_dual) ->
  #First group all records by the compond key [population, period, dx, dy]
  # Only if these parameters are the same, two gliders can be equivalent
  merged = 0
  filtered_report = []
  key2gliders = {}
  for record in report
    {result} = record
    rle = record.key
    key = "#{result.cells.length} #{result.period} #{result.dx} #{result.dy}"
    gliders = key2gliders[key] ? (key2gliders[key] = [])
    gliders.push record
  for _, records of key2gliders
    if records.length > 1
      merged += _doMergeNonUnique records, rule, mk_dual, filtered_report
    else
      filtered_report.push records[0]
  return [filtered_report, merged]


_figureEvolutions = (cells, rule, period) ->
  cells = ([x,y,1] for [x,y] in cells)
  evols = [cells]
  if mk_dual?
    evols.push mk_dual cells
  for i in [0...period-1]
    cells = evaluateLabelledCellList rule, cells, i%2
    cells_norm = if i%2 is 1 then cells else Cells.togglePhase cells # is 1! because iteration was already calculated!
    evols.push cells_norm
  evols
      
_doMergeNonUnique = (records, rule, mk_dual, report) -> #report is output!
  #In this function, records contains list of records with the similar parameters: speed, population, period.
  #Records will contain at least 2 different records
  #process.stderr.write "      found group of #{records.length} gliders\n"
  key2record = {}
  merged = 0  
  for record in records
    {result} = record
    rle = record.key
    old_record = key2record[ rle ]
    if old_record?
      old_record.count += record.count
      merged += 1
    else
      report.push record
      #process.stdout.write "    Figure:\n"
      for fig in _figureEvolutions result.cells, rule, result.period
        rle = Cells.to_rle Cells.normalize fig
        #process.stdout.write "      register RLE: #{rle}\n"
        key2record[rle] = record
        if mk_dual?
          fig_dual = mk_dual fig, result.dx, result.dy
          rle = Cells.to_rle Cells.normalize fig_dual
          key2record[rle] = record
  return merged

##################
# top-level code #
##################
pth = "/home/dim/Dropbox/Math/rev-ca/"
consolidated = consolidateReports (pth + f for f in [
  "report3.json", "report1.json", "report2.json", "report-128x128-chrome-big.json", "report-256x256-chrome-big.json"])

consolidated = filterComposites consolidated, rule
consolidated = mergeDualGliders consolidated
process.stderr.write "Total records after merge: #{consolidated.length}\n"

process.stderr.write "Merging non-unique representations of a gliders\n"
[consolidated, merges] = mergeNonUniqueNormalizations consolidated, rule, makeDualGlider
process.stderr.write "   merged #{merges} records; new size: #{consolidated.length}\n"

fs.writeFileSync "consolidated-singlerot.json", JSON.stringify consolidated

process.stdout.write "Consolidation of results complete, #{consolidated.length} figures found\n"
