# This is a browser-only module
((exports)->
  ###### imports #######
  {MargolusNeighborehoodField, Array2d} = this.reversible_ca
  {div, mod} = this.math_util
  ######################

  ###
  Draw a block of field cells on a canvas
  ###
  exports.FieldView = class FieldView
    constructor: (@field) ->
      @cell_colors = ["#888", "#ff0"]
      @bg_style = "#444"
      @cell_size = 4
      @cell_spacing = 1
      @old_field = null
      @show_grid = true
      @grid_colors = ["rgb(153,153,153)", "gray"]
    
    ###
    Return cell index from coordinates
    ###
    xy2index: (x, y) ->
      cs = @cell_size
      [div(x, cs), div(y, cs)]

    draw_grid: (context, x0, y0, x1, y1) ->
      size = @cell_size
      return if size <= @cell_spacing
      xmax = size * x1
      ymax = size * y1
      xmin = size * x0
      ymin = size * y0
      drawGridVrt = (xstart, style) ->
        context.beginPath()
        context.strokeStyle = style
        for x in [xstart ... xmax] by (size*2)
          context.moveTo x + 0.5, ymin + 0.5
          context.lineTo x + 0.5, ymax + 0.5
        context.stroke()

      drawGridHrz = (ystart, style) ->
        context.beginPath()
        context.strokeStyle = style
        for y in [ystart ... ymax] by (size*2)
          context.moveTo xmin + 0.5, y + 0.5
          context.lineTo xmax + 0.5, y + 0.5
        context.stroke()

      context.lineWidth = @cell_spacing
      drawGridHrz ymin + size - 1, @grid_colors[y0 % 2]
      drawGridVrt xmin + size - 1, @grid_colors[x0 % 2]
      drawGridHrz ymin + size + size - 1, @grid_colors[(y0 + 1) % 2]
      drawGridVrt xmin + size + size - 1, @grid_colors[(x0 + 1) % 2]

    grid2screenX: (xGrid) ->
      @size * xGrid

    grid2screenY: (yGrid) ->
      @size * yGrid

    draw_box: (context, x0, y0, x1, y1) ->
      size = @cell_size
      spacing = @cell_spacing
      data = @field.data
      old_field = @get_old_field().data
      for i in [y0 ... y1] by 1
        idx = @field.cell_index(x0, i)
        for j in [x0 ... x1] by 1
          state = data[idx]
          unless old_field[idx] is state
            @draw_cell context, size * j, size * i, size, state
            old_field[idx] = state
          idx++
      @draw_grid context, x0, y0, x1, y1  if spacing > 0

    draw: (context) ->
      @draw_box context, 0, 0, @field.width, @field.height

    get_old_field: ->
      field = @field
      if not @old_field or @old_field.width isnt field.width or @old_field.height isnt field.height
        od = new Array2d(field.width, field.height)
        od.fill -1
        @old_field = od
        return od
      else
        return @old_field

    draw_cell: (context, x, y, size, state) ->
      context.fillStyle = @cell_colors[state]
      context.fillRect x, y, size, size

    invalidate: ->
      @old_field.fill -1  if @old_field

    erase_background: (context) ->
      cs = @cell_size
      context.fillStyle = @bg_style
      context.fillRect 0, 0, @field.width * cs, @field.height * cs
)(this["field_view"] = {})
