# This is a browser-only module
  ###### imports #######
  {MargolusNeighborehoodField, Array2d} = require "./reversible_ca"
  {div, mod} = require "./math_util"
  ######################

  ###
  Draw a block of field cells on a canvas
  ###
  exports.FieldView = class FieldView
    constructor: (@field) ->
      @cell_colors = ["#888", "#ff0"]
      @cell_size = 4
      @grid_width = 1
      @old_field = null
      @grid_colors = ["rgb(153,153,153)", "gray"]
    
    ###
    Return cell index from coordinates
    ###
    xy2index: (x, y) ->
      cs = @cell_size
      [div(x, cs), div(y, cs)]

    draw_grid: (context, x0, y0, x1, y1) ->
      size = @cell_size
      spacing = @grid_width
      return if size <= @grid_width
      xmax = size * x1
      ymax = size * y1
      xmin = size * x0
      ymin = size * y0
      drawGridVrt = (xstart, style) ->
        context.fillStyle = style
        for x in [xstart ... xmax] by (size*2)
          context.fillRect x, ymin, spacing, (ymax-ymin)

      drawGridHrz = (ystart, style) ->
        context.fillStyle = style
        for y in [ystart ... ymax] by (size*2)
          context.fillRect xmin, y, xmax-xmin ,spacing

      drawGridHrz ymin + size - 1, @grid_colors[y0 % 2]
      drawGridVrt xmin + size - 1, @grid_colors[x0 % 2]
      drawGridHrz ymin + size + size - 1, @grid_colors[(y0 + 1) % 2]
      drawGridVrt xmin + size + size - 1, @grid_colors[(x0 + 1) % 2]

    draw_box: (context, x0, y0, x1, y1) ->
      size = @cell_size
      spacing = @grid_width
      data = @field.data
      old_field = @get_old_field().data
      prev_state = 255
      for i in [y0 ... y1] by 1
        idx = @field.cell_index(x0, i)
        for j in [x0 ... x1] by 1
          state = data[idx]
          unless old_field[idx] is state
            #@draw_cell context, size * j, size * i, size, state
            if state isnt prev_state
              prev_state = state
              context.fillStyle = @cell_colors[state]
            context.fillRect size * j, size * i, size, size
            old_field[idx] = state
          idx++
      @draw_grid context, x0, y0, x1, y1  if spacing > 0

    draw: (context) ->
      @draw_box context, 0, 0, @field.width, @field.height

    get_old_field: ->
      field = @field
      if not @old_field or @old_field.width isnt field.width or @old_field.height isnt field.height
        od = new Array2d(field.width, field.height)
        od.fill 255
        @old_field = od
        return od
      else
        return @old_field

    draw_cell: (context, x, y, size, state) ->
      context.fillStyle = @cell_colors[state]
      context.fillRect x, y, size, size

    invalidate: ->
      @old_field.fill 255  if @old_field
