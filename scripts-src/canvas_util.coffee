  #taken from http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
  exports.getCanvasCursorPosition = (e, canvas) ->
    if e.type is "touchmove" or e.type is "touchstart" or e.type is "touchend"
      e=e.touches[0]
    if e.clientX?
      rect = canvas.getBoundingClientRect()
      return [e.clientX - rect.left, e.clientY - rect.top]
        
  # makes a valiant effort to change an x,y pair from an event to an array of
  # size two containing the resultant x,y offset onto the canvas.
  # There are events, like key events for which this will not work.  They
  # are not mouse events and don't have the x,y coordinates.
  exports.getCanvasCursorPosition1 = (e, canvas) ->
    #Shortcut. Deprecated?
    #if e.layerX?
    #  return [e.layerX, e.layerY]
    if e.type is "touchmove" or e.type is "touchstart" or e.type is "touchend"
      x = e.touches[0].pageX
      y = e.touches[0].pageY
    else if e.pageX? # or e.pageY?
      x = e.pageX
      y = e.pageY
    else
      dbody = document.body
      delem = document.documentElement
      x = e.clientX + dbody.scrollLeft + delem.scrollLeft
      y = e.clientY + dbody.scrollTop  + delem.scrollTop  
    # Convert to coordinates relative to the canvas
    x -= canvas.offsetLeft
    y -= canvas.offsetTop
    [x, y]
