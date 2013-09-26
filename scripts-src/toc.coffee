###
@author Louis Stowasser <louisstow@gmail.com>
License: MIT
###
{DomBuilder} = require "./dom_builder"
exports.generateTOC = (rootNode, startLevel) ->
  lastLevel = 0
  startLevel = startLevel or 2 #which H# tag to start indexing.
  dom = new DomBuilder
  dom.tag "ul"
  dom.tag "li"
  
  #loop every node in rootNode
  for node, i in rootNode.childNodes
    #skip nodes that aren't <H#> tags
    continue  if not node.tagName or not /H[0-9]/.test(node.tagName)
    level = parseInt node.tagName.substr(1), 10
    
    #only parse at the start level
    continue  if level < startLevel
    
    #if the <H#> tag has any children, take the text of the first child
    #else grab the text of the <H#> tag
    name = node.textContent
    
    #skip this node if there is no name
    continue unless name
    
    #create a string that can be used for an anchor hash based
    #on the name but without dots or spaces
    hashable = name.replace(/[\.\s]/g, "-")
    
    #set the id of the <H#> tag to this hash
    node.id = hashable
    
    #generate the HTML
    if level is lastLevel
      dom.end() #li
      dom.tag("li")
    else if level < lastLevel
      lvl = level
      while lvl < lastLevel
        dom.end().end()
        lvl += 1
      dom.end().tag("li")
    else if level > lastLevel
      lvl = level
      while lvl < lastLevel
        dom.tag("ul").tag("li")
        lvl -= 1

    dom.tag("a").CLASS('lvl' + level).a("href", "#" + hashable).text(name).end()
    lastLevel = level

  dom.end()
  dom.finalize()
