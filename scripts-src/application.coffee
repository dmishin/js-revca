#Import modules
# This applicaiton module will only work in the browser
  ##### Imports #####
  {parse, NamedRules, Rule2Name} = require "./rules"
  {Cells, Point, splitPattern, getDualTransform, evaluateCellList} = require "./cells"
  {MargolusNeighborehoodField, Array2d} = require "./reversible_ca"
  {div, mod, line_pixels, rational2str, getReadableFileSizeString, cap} = require "./math_util"
  {FieldView} = require "./field_view"
  {getCanvasCursorPosition} = require "./canvas_util"
  {DomBuilder} = require "./dom_builder"
  {parseUri} = require "./parseuri"
  {parse_rle, remove_whitespaces} = require "./rle"
  {GIFEncoder} = require "./ext/GIFEncoder"
  {exactPalette} = require "./ext/ExactPaletteQuant"
  ###################
  # Utils
  E = (id) -> document.getElementById(id)
  nodefault = (handler) -> (e) ->
    e.preventDefault()
    handler e
  makeElement = (tag, attrs, text) ->
    elem = document.createElement(tag)
    if attrs?
      for [attr, aval] in attrs
        elem.setAttribute attr, aval
    if text?
      elem.appendChild document.createTextNode text
    elem
  #I am learning JS and want to implement this functionality by hand
  # Remove class from the element
  removeClass = (e, c) ->
    classes = []
    for ci in e.className.split " "
      if c isnt ci
        classes.push ci
    e.className = classes.join " "
    
    null
  addClass = (e, c) ->
    classes = e.className
    e.className =
      if (classes = e.className) is ""
        c
      else
        classes + " " + c
    null

  selectValue2Option = (elem) ->
    val2opt = {}
    for opt in elem.options
      val2opt[opt.value] = opt
    val2opt
    
  selectOption = (elem, value, value0) ->
    val2opt = selectValue2Option elem
    o = val2opt[value]
    if value0? and (not o?)
      o = val2opt[value0]
    if o?
      o.selected = true
      
  selectOrAddOption = (elem, value, nameToAdd=value) ->
    val2opt = selectValue2Option elem
    unless (option = val2opt[value])?
      option = new Option(nameToAdd, value)
      elem.options[elem.options.length] = option
    option.selected = true
      
      
  idOrNull = (elem)->
    if elem is null
      null
    else
      elem.getAttribute "id"
      
  spaceshipType = (dx, dy) ->
    unless dx?
      "unknown"
    else if dx is 0 and dy is 0
      "oscillator"
    else if dx is 0 or dy is 0
      "orthogonal spaceship"
    else if Math.abs(dx)==Math.abs(dy)
      "diagonal spaceship"
    else
      "slant spaceship"

  class ButtonGroup
    constructor: (containerElem, tag, selectedId=null, @selectedClass="btn-selected")->
      if selectedId isnt null
        addClass (@selected = E selectedId), @selectedClass
      else
        @selected = null
        
      @handlers = change: []

      for btn in containerElem.getElementsByTagName tag
        btn.addEventListener "click", @_btnClickListener btn
      return
    
    _btnClickListener: (newBtn) -> (e) =>
      #newBtn = (e.target ? e.srcElement)
      oldBtn = @selected
      newId = idOrNull newBtn
      oldId = idOrNull oldBtn
      if newId isnt oldId
        if oldBtn isnt null then removeClass oldBtn, @selectedClass
        if newBtn isnt null then addClass newBtn, @selectedClass
        @selected = newBtn
        for handler in @handlers.change
          handler( e, newId, oldId )
        return
          
    addEventListener: (name, handler)->
      unless (handlers = @handlers[name])?
        throw new Error "Hander #{name} is not supported"
      handlers.push handler
      

    
  class DelayedHandler
    constructor: (@delayMs, @handler) ->
      @timerId = null
    fireEvent: (e) ->
      @cancel()
      @timerId = setTimeout (=>
        @handler e
        ), @delayMs
    cancel: ->
      if (t=@timerId) isnt null
        clearTimeout t
        @timerId = null

  addDelayedListener = ( element, eventNames, delayMs, listener ) ->
    delayedListener = new DelayedHandler delayMs, listener
    handler = (e) -> delayedListener.fireEvent e
    for eName in eventNames
      element.addEventListener eName, handler
    null
  predefinedRules = [
      ["Billiard Ball Machine", parse("0,8,4,3,2,5,9,7,1,6,10,11,12,13,14,15") ]
      ["Bounce gas", parse("0,8,4,3,2,5,9,14, 1,6,10,13,12,11,7,15")],
      ["HPP Gas", parse("0,8,4,12,2,10,9, 14,1,6,5,13,3,11,7,15")],
      ["Rotations", parse("0,2,8,12,1,10,9, 11,4,6,5,14,3,7,13,15")],
      ["Rotations II", parse("0,2,8,12,1,10,9, 13,4,6,5,7,3,14,11,15")],
      ["Rotations III", parse("0,4,1,10,8,3,9,11, 2,6,12,14,5,7,13,15")],
      ["Rotations IV", parse("0,4,1,12,8,10,6,14, 2,9,5,13,3,11,7,15")],
      ["String Thing", NamedRules.stringThing],
      ["String Thing II", parse("0,1,2,12,4,10,6,7,8, 9,5,11,3,13,14,15")],
      ["Swap On Diag", parse("0,8,4,12,2,10,6,14, 1,9,5,13,3,11,7,15")],
      ["Critters", NamedRules.critters],
      ["Tron", NamedRules.tron],
      ["Double Rotate", NamedRules.doubleRotate],
      ["Single Rotate", NamedRules.singleRotate]]      
  # Main application class
  class GolApplication
      constructor: (field_size, rule_string, container_id, canvas_id, overlay_id, time_display_id) ->
    
        #Application state and initialization
        @rule = null
        @stable_rule = null
        @rule_phase = 0        
        @stable_enabled = false

        @gol = new MargolusNeighborehoodField(new Array2d(field_size ...))
        @generation = 0
        @gol.clear()
        @view = new FieldView(@gol.field)
        @step_size = 1
        @step_delay = 50
        @field_player = null
        @field_player_proc = null
        @canvas = E(canvas_id)
        @canvas_overlay = E(overlay_id)
        @canvas_container = E(container_id)
        @time_display = time_display_id and E(time_display_id)
        @mouse_tools =
          draw: new ToolDraw(this)
          select: new ToolSelect(this)
          stamp: new ToolStamp(this)
          eraser: new ToolEraser(this, 5)
        @mouse_tool = null #tool_toggler;
        @selection = null
        @encoder = null
        @spaceship_catcher = null

        @library = new LibraryPane(E("pattern-report"), E("library-size"), this)
        @buffer = new BufferPane(E("active-pattern-canvas"))
        @subRuleControls = []
        @set_rule parse rule_string
        @ghost_click_detector = new GhostClickDetector()
        
      setSize: (cols, rows) ->
        RECOMMENDED_WIDTH = 800
        RECOMMENDED_HEIGHT = 600
        unless cols is @gol.field.width and rows is @gol.field.height
          @gol = new MargolusNeighborehoodField(new Array2d(cols, rows))
          @gol.clear()
          @view.field = @gol.field
          #Update cell size, if needed
          max_cell_size = Math.min( RECOMMENDED_WIDTH/cols, RECOMMENDED_HEIGHT/rows) | 0
          if max_cell_size < @view.cell_size
            @view.cell_size = max_cell_size
            if max_cell_size <= 2
              @view.grid_width = 0 #disable grid.
          @adjustCanvasSize()
          ctx = @canvas.getContext("2d")
          @view.invalidate()
          @view.draw ctx

          
      startPlayer: (direction) ->
          @stopPlayer() if @field_player
          @field_player_proc =
            switch direction
              when 1 then => @doStep()
              when -1 then => @doReverseStep()
              else throw new Error("Bad direction:" + direction)
          @field_player = window.setInterval(@field_player_proc, @step_delay)

      isPlaying: -> @field_player?

      stopPlayer: ->
          if @field_player
            window.clearInterval @field_player
            @field_player = null

      updateCanvas: -> @view.draw @canvas.getContext("2d")

      updateCanvasBox: (x0, y0, x1, y1) ->
          @view.draw_box @canvas.getContext("2d"), x0, y0, x1, y1

      parseCellSize: (sel_style) ->
          [sw, sh] = st = sel_style.split(",")
          throw new Error "Value is incorrect: #{sel_style}" unless st.length is 2
          [parseInt(sw, 10), parseInt(sh, 10)]

      adjustCanvasSize: ->
          w = @gol.field.width * @view.cell_size
          h = @gol.field.height * @view.cell_size
          @canvas_container.style.width = "#{w}px"
          @canvas_container.style.height = "#{h}px"
          @canvas_overlay.width = @canvas.width = w
          @canvas_overlay.height = @canvas.height = h

      setCellSize: (size) ->
          @view.cell_size = size
          @adjustCanvasSize()
          ctx = @canvas.getContext("2d")
          @view.invalidate()
          @view.draw ctx
          
      setShowGrid: (show) ->
        @view.grid_width = if show then 1 else 0
        ctx = @canvas.getContext("2d")
        @view.invalidate()
        @view.draw ctx


      doStepImpl: (rule, step_size) ->
        phase = @rule_phase
        for i in [0...step_size]
          @gol.transform rule.rules[phase]
          @rule_phase = phase = (phase+1) % rule.size()
          @onStep phase
        @generation += step_size
        

      getActiveRule: ->
        if @stable_enabled
          @stable_rule
        else
          @rule
          
      onStep: (rulesetPhase)->
        if (gc = @spaceship_catcher)
          if (not @rule_is_stable) and not @stable_enabled
            alert "Disabling catcher. Enable stabilization to make it available"
            @disable_spaceship_catcher()
          else
            gc.scan @gol
          
      doStep: ->
          @doStepImpl @getActiveRule(), @step_size
          @showRulesetPhase()
            
          if @spaceship_catcher? and @generation >= @spaceship_catcher.reseed_period
            @generation = 0
            @rule_phase = 0
            @do_clear()
            @random_fill_selection parseFloat(E("random-fill-percent").value)*0.01
          @updateCanvas()
          @update_time()
          @recordFrame()

      doReverseStepImpl: (irule, step_size)->
        phase = @rule_phase
        for i in [0...step_size]
          phase = mod (phase-1), irule.size()
          @gol.untransform irule.rules[phase]
        @rule_phase = phase
        @generation -= @step_size

      getActiveRuleInv: ->
        if @stable_enabled
          @inverse_stable_rule
        else
          @inverse_rule
      
      doReverseStep: ->
        unless @inverse_rule
          alert "Rule is not reversible"
          @stopPlayer()
          return
        @doReverseStepImpl @getActiveRuleInv(), @step_size
        @showRulesetPhase()
        @updateCanvas()
        @update_time()
        @recordFrame()

      recordFrame: ->
        return unless @encoder?
        @encoder.addFrame @canvas.getContext("2d")
        sizeElem = document.getElementById("gif-size")
        if sizeElem?
          sizeElem.innerHTML = getReadableFileSizeString(@encoder.stream().getSize())
          
      setMouseTool: (tool) ->
          @mouse_tool.on_disable() if  @mouse_tool
          @mouse_tool = tool
          tool.on_enable() if tool

      setDelay: (delay) ->
          if delay? and delay <=0 then throw new Error "Bad delay value: "+delay
          return if delay is @step_delay
          @step_delay = delay
          if @isPlaying()
            window.clearInterval @field_player
            @field_player = window.setInterval(@field_player_proc, @step_delay)

      update_time: ->
          @time_display.innerHTML = "" + @generation  if @time_display

      reset_time: ->
          @generation = mod(@generation, 2) #Never try to change oddity of the generation
          @update_time()

      #Play forward until rule phase is 0
      # Does nothing, if already 0
      nullifyRulesetPhase: ->
        old_step = @step_size
        @step_size = mod (-@rule_phase), @getActiveRule().size()
        try
          @doStep()
        finally
          @step_size = old_step
        return
        
      set_rule_str: (srule) ->
        try
          @set_rule parse srule
        catch e
          alert "Failed to set rule: #{e}"
          
      _updateRuleControls: ->
        rule = @rule
        if rule.size() isnt @subRuleControls.length
          #need to rebuild controls for sub-rules
          @_createSubRuleControls rule.size()
        for control, i in @subRuleControls
          control.input.value = rule.rules[i].stringify()
          selectOption control.select, @rule.rules[i].stringify(), ""            

        
      set_rule: (rule) ->
        @rule = rule
        @rule_is_stable = rule.is_vacuum_stable()
        @rule_phase = 0
        @inverse_rule =
          try
            rule.reverse()
          catch
            null
        
        @stable_rule = rule.stabilize_vacuum()
        try
          @inverse_stable_rule = @stable_rule.reverse()
        catch e
          @inverse_stable_rule = null
        #Updating GUI according to the rule

        @_updateRuleControls()
          
        selectOption E("select-rule"), rule.stringify(), ""
        #console.log "Selection rule #{rule.stringify()}"

        E("stable-sub-rules").innerHTML = ""
        show_rule_diagram rule, E("function_display")
        show_rule_properties rule, E("function_properties")
        #console.log "Showed rule diagram for rule #{rule.stringify()}"

        #By default, enable rulesets, if it makes any difference
        if not @rule_is_stable
          E("stablize-rule").checked = true
          @stable_enabled = true
          @show_rule_stabilization()
          E("rule-stabilization-pane").style.display = "block"
        else
          @stable_enabled = false
          E("rule-stabilization-pane").style.display = "none"
      setRuleFromControls: ->
        ruleStr = (c.input.value for c in @subRuleControls).join ";"
        @set_rule_str ruleStr
        
      _removeSubRule: (index) ->
        @rule.rules.splice index, 1
        @set_rule @rule
      _duplicateSubRule: (index)->
        subRule = @rule.rules[index]
        @rule.rules.splice index, 0, subRule
        @set_rule @rule
        
      _reverseSubRule: (index) ->
        try
          @rule.rules[index] = @rule.rules[index].reverse()
          @set_rule @rule
        catch e
          alert "Failed to reverse rule: #{e}"
        
      _createSubRuleControls: (n) ->
        container = E "table-sub-rules"
        dom = new DomBuilder
        dom.tag("tbody")
        controls = []
        for i in [0...n] by 1
          dom.tag("tr")
            .tag("td").text("#{i+1})").end()
            .tag("td")
              .tag("input").CLASS("rule-input").store("subrule_input").end()
            .end()
            .tag("td")
            .tag("button").store("subrule_reverse").text("-T").a("title","Inverse sub-rule").end()          
            .tag("button").store("subrule_duplicate").text("+").a("title","Duplicate sub-rule").end()          
          #Don't add remove button, if number of rules is 1.
          if n > 1 
            dom.tag("button").store("subrule_delete").text("-").a("title","Remove sub-rule").end()
          dom.tag("select").store("subrule_select").end()
             .end().end() #td, tr
          #assign event handlers
          do (i) =>
            #warning: mind `?`, button can be absent
            vars = dom.vars
            vars.subrule_delete?.addEventListener "click", (e) => @_removeSubRule i
            vars.subrule_duplicate.addEventListener "click", (e) => @_duplicateSubRule i
            vars.subrule_reverse.addEventListener "click", (e) => @_reverseSubRule i
            vars.subrule_input.addEventListener "change", (e) => @setRuleFromControls()
            fill_rules dom.vars.subrule_select, predefinedRules
            vars.subrule_select.addEventListener "change", (e) =>
              value = (e.target or e.srcElement).value
              if value isnt ""
                @rule.rules[i] = parse(value).rules[0]
                @set_rule @rule
          #store controls
          controls.push
            input: dom.vars.subrule_input
            select: dom.vars.subrule_select
        dom.end()
        container.innerHTML = ""
        container.appendChild dom.finalize()
        @subRuleControls = controls
        
      enableRuleset: (enabled) ->
        if enabled is @stable_enabled
          return
          
        @rule_phase = mod @generation, @getActiveRule().size()
        @showRulesetPhase()
          
        vacuum_cycle = @rule.vacuum_cycle()
        @gol.apply_xor vacuum_cycle[@rule_phase]
        @updateCanvas()
        @stable_enabled = enabled
          
      showRulesetPhase: -> E("vacuum-phase").innerHTML = @rule_phase
    
      show_rule_stabilization: ->
        dom = new DomBuilder
        dom.tag("table").CLASS("library-table")
          .tag("thead")
          .tag("th").text("Phase").end()
          .tag("th").text("Vacuum").end()
          .tag("th").text("Rule").end()
        .end()

        dom.tag("tbody")
        vacuum_cycle = @rule.vacuum_cycle()
        for srule, i in @stable_rule.rules
           dom.tag("tr")
              .tag("td").text(i).end()
              .tag("td").tag("span").CLASS(cells_icon vacuum_cycle[i]).end().end()
              .tag("td").text(srule.stringify()).end()
              .end()
        dom.end().end()
        E("stable-sub-rules").appendChild dom.finalize()
        
      do_clear: ->
          @gol.clear()
          @updateCanvas()
          @update_time()

      attach_listeners: ->
          widget = @canvas_container
          self = this
          widget.addEventListener "mousedown", nodefault ((e) ->
            unless self.ghost_click_detector.isGhost
              self.mouse_tool.on_mouse_down e
            ), false
          widget.addEventListener "mouseup", nodefault((e) ->
            unless self.ghost_click_detector.isGhost
              self.mouse_tool.on_mouse_up e
            ), false
          widget.addEventListener "mousemove", nodefault((e) -> self.mouse_tool.on_mouse_move e), false
          widget.addEventListener "mouseout", nodefault((e) -> self.mouse_tool.on_mouse_out e), false

          widget.addEventListener "touchstart", ((e) -> self.mouse_tool.on_touch_start e ), false
          widget.addEventListener "touchend", ((e) -> self.mouse_tool.on_touch_end e ), false
          widget.addEventListener "touchmove", ((e) -> self.mouse_tool.on_touch_move e ), false
          widget.addEventListener "touchleave",  ((e) -> self.mouse_tool.on_touch_leave e ), false
          @ghost_click_detector.addListeners widget
          
      ###
      Load initial state from the URL parameters
      ###
      load_parameters: ->
          #console.log "Loadung parameters from URL"
          keys = parseUri(window.location).queryKey
          #load RLE code of the initial field
          if keys.size?
            sz = keys.size.split 'x'
            throw new Error "Size must have form WIDTHxHEIGHT" unless sz.length is 2
            c = parseInt sz[0], 10
            r = parseInt sz[1], 10
            throw new Error "Width and height must be even"  if r % 2 isnt 0 or c % 2 isnt 0
            @gol = new MargolusNeighborehoodField(new Array2d(c, r))
            @gol.clear()
            @view = new FieldView(@gol.field)
            #console.log "Updated field width to #{keys.size}"
              
          if keys.cell_size?
            [@view.cell_size, @view.grid_width] =
              @parseCellSize(keys.cell_size)
          if keys.colors?
            colors = keys.colors.split ";"
            if colors.length  isnt 4
              throw new Error "Colors attribute must have 4 ';'-separated values: colors of cells and colors of grid"
            @view.cell_colors[0] = colors[0]
            @view.cell_colors[1] = colors[1]
            @view.grid_colors[0] = colors[2]
            @view.grid_colors[1] = colors[3]
          
            
          if keys.rle?
            x0 = if keys.rle_x0 then parseInt(keys.rle_x0, 10) else 0
            y0 = if keys.rle_y0 then parseInt(keys.rle_y0, 10) else 0
            parse_rle keys.rle, (x,y) =>
              @gol.field.set_wrapped x0+x, y0+y, 1
            #console.log "Put RLE"
              
          if keys.phase?
            phase = parseInt keys.phase, 10
            unless phase in [0,1]
              alert "Incorrect phase value #{phase}, must be 0 or 1"
            @gol.phase = phase
            @generation = phase
            
          if keys.rule?
            try
              r = NamedRules[ keys.rule ] ? parse(keys.rule, ",")
              @set_rule r
            catch e
              alert "Incorrect rule: #{keys.rule}: #{e}"
          else
            if (rule = E("select-rule").value) isnt ""
              @set_rule_str rule
          if keys.ruleset_phase?
            if not keys.rule?
              alert "Rule must be specified, when using ruleset_phase"
            else
              phase = parseInt keys.ruleset_phase
              unless phase >=0 and phase < @stable_rule.size()
                alert "Ruleset phase #{phase} is outside of allowed region"
              else
                @stable_enabled = true
                @rule_phase = phase
                @showRulesetPhase()
                
          if keys.frame_delay?
            try
              @setDelay parseInt keys.frame_delay, 10
            catch e
              alert e
          if keys.step?
            try
              s = parseInt keys.step, 10
              if not s? or s<=0 then throw new Error "Incorrect step value:"+s
              @step_size = s
            catch e
              alert e
      encode_state_in_url: ->
        urlArgs = []

        srule = @rule.stringify()
        urlArgs.push "rule=#{srule}"
        
        fld = @gol.field
        pattern = fld.get_cells 0, 0, fld.width, fld.height
        if pattern.length > 0
          [x0, y0] = Cells.bounds pattern
          srle = Cells.to_rle Cells.offset pattern, -x0, -y0
          urlArgs.push "rle_x0=#{x0}"
          urlArgs.push "rle_y0=#{y0}"
          urlArgs.push "rle=#{srle}"
        urlArgs.push "step=#{@step_size}"
        urlArgs.push "frame_delay=#{@step_delay}"
        urlArgs.push "size=#{fld.width}x#{fld.height}"
        urlArgs.push "cell_size=#{@view.cell_size},#{@view.grid_width}"
        urlArgs.push "phase=#{@gol.phase}"
        if @stable_enabled
          urlArgs.push "ruleset_phase=#{@rule_phase}"

        loc = ""+window.location
        if (anchorStartsAt = loc.indexOf "#") isnt -1
          loc = loc.substr 0, anchorStartsAt
        argsStartAt = loc.indexOf "?"
        baseUrl = 
          if argsStartAt is -1 then loc else loc.substr 0, argsStartAt

        return baseUrl + "?" + (urlArgs.join "&")
        
          
      initialize: ->
          @load_parameters()
          @adjustCanvasSize()
          @setMouseTool @mouse_tools.draw
          @updateCanvas()
          @attach_listeners()
          @update_controls()
          
      update_controls: ->
          #Update GUI controls
          @_updateRuleControls()

          selectOrAddOption E("speed-show-every"), @step_size
          selectOrAddOption E("speed-frame-delay"), @step_delay, "#{@step_delay}ms"
              
          sz = @gol.field.size()
          selectOrAddOption E("select-size"), JSON.stringify(sz), "#{sz[0]} x #{sz[1]}"
          
          selectOrAddOption E("select-style"), @view.cell_size
          E("show-grid").checked = (@view.grid_width > 0)
          @updateLibrariesList()
                    
      clear_selection: ->
          if sel = @selection
              @gol.field.fill_box sel[0], sel[1], sel[2], sel[3], 0
              @updateCanvasBox sel ...

      random_fill_selection: (p) ->
          if p < 0 or p > 1 or isNaN(p)
            alert "Wrong percentage: #{p}"
            return
          if sel = @selection
            @gol.field.random_fill sel[0], sel[1], sel[2]+1, sel[3]+1, p
            @updateCanvasBox sel ...


      _getAnalyzerMaxSteps: ->
        maxSteps = parseInt E("analysis-max-steps").value, 10
        if isNaN maxSteps
          maxSteps = 2048
          alert "Incorrect value of the analysis depth, will use #{maxSteps}"
        maxSteps
        
      enable_spaceship_catcher: ->
        if (not @rule_is_stable) and not @stable_enabled
          alert "Enable rule stabilization to run catcher"
          return
        if @spaceship_catcher is null
          maxSteps = @_getAnalyzerMaxSteps()
          on_spaceship = (pattern)  =>
            rule = @rule
            pattern = @_promoteToZeroPhase pattern
            if result=Cells.analyze(pattern, rule, {max_iters:maxSteps})
              if result.period?
                if result.dx isnt 0 or result.dy isnt 0
                  @library.put result, rule
                  # console.log "#### Added ss: dx=#{result.dx} dy=#{result.dy}"
            null
          try
            reseed_period = parseInt E("catcher-reseed-period").value, 10
            max_spaceship_sz = parseInt E("catcher-max-spaceship-size").value, 10
            if isNaN reseed_period or reseed_period <= 0 then throw new Error "Reseed period negative"
            if (not max_spaceship_sz?) or (isNaN max_spaceship_sz) then throw new Error "Bad max spaceship value"
            @spaceship_catcher = new SpaceshipCatcher on_spaceship, max_spaceship_sz, reseed_period
            E("catcher-reseed-period").readOnly = true
            E("catcher-max-spaceship-size").readOnly = true
            addClass E("toggle-catcher"), "btn-selected"
          catch e
            alert "Failed to enable catcher:" + e
            
      disable_spaceship_catcher: ->
        if @spaceship_catcher isnt null
          @spaceship_catcher = null
          E("catcher-reseed-period").readOnly = false
          E("catcher-max-spaceship-size").readOnly = false
          removeClass E("toggle-catcher"), "btn-selected"
          
      clear_nonselection: ->
          if sel = @selection
            @gol.field.fill_outside_box sel[0], sel[1], sel[2], sel[3], 0
            @updateCanvas()

      start_gif_recorder: ->
        return if @encoder
        @encoder = encoder = new GIFEncoder()
        encoder.setPalette exactPalette
        encoder.setRepeat 0 #0 -> loop forever //1+ -> loop n times then stop
        encoder.setDelay @step_delay #go to next frame every n milliseconds
        encoder.start()
        @recordFrame() #Add first frame
      ###
      Stop recorder and show window or return data URL
      ###
      stopGifRecorder: ->
        unless @encoder
          alert "Not started"
          return
        encoder = @encoder
        @encoder = null
        encoder.finish()
        data_url = "data:image/gif;base64," + encoder.stream().getB64Data()
        out = E "gif-output"
        out.innerHTML = ""
        out.appendChild makeElement "img", [["src", data_url], ["alt", "GIF animation"]]
          
      ##Remove the recorded GIF image
      gifRecorderClear: -> E("gif-output").innerHTML = ""

      #Evaluate pattern several steps until its ruleset phase is 0
      _promoteToZeroPhase: (pattern) ->
        #TODO
        rule_phase = @rule_phase
        field_phase = 0 #Assume that pattern it shifted to be in the 0 field phase.
        rule = @getActiveRule()
        while rule_phase isnt 0
          pattern = evaluateCellList rule.rules[rule_phase], pattern, field_phase
          rule_phase = (rule_phase+1)%rule.size()
          field_phase ^= 1
        if field_phase
          pattern = Cells.offset pattern,1,1
        Cells.sortXY pattern
        
      analyzeSelection: ->
        cells = @getSelectedCells()
        return if cells.length is 0
        root = E "analysis-report-area"
        root.innerHTML = "<div style='text-align:center'><span class='icon-wait'>Analysing...</span></div>"
        E("analysis-result").style.display = "block"

        #Promote phase of the selection to 0, if ruleset is enabled
        cells = @_promoteToZeroPhase cells

        #Delay analysis
        window.setTimeout (=>
          @analysis_result = result = Cells.analyze(cells, @rule, {max_iters:@_getAnalyzerMaxSteps()})

          makeCanvas = (imgW, imgH) -> makeElement "canvas", [["width", imgW], ["height", imgH]]
          canv = drawPatternOnCanvas makeCanvas, result.cells, [128, 96], [1, 24], 1
          try
            in_library = (@library.has result) or (@library.hasDual result, @rule)
          catch e
            alert "Library lookup failed: #{e}"

          dom = new DomBuilder
          dom.tag("div").CLASS("pattern-background").append(canv).end()
          dom.tag("ul")
          dom.tag("li").text("Result: ").text(result.resolution).end()            
          dom.tag("li").text("Pattern type: ").text(spaceshipType result.dx, result.dy).end()
          dom.tag("li").text("Population: #{cells.length} cells").end()
          dom.tag("li").text("Period: ").text(result.period ? "unknown").end()
          if result.dx? and (result.dx or result.dy)
            dom.tag("li").text("Δx=#{result.dx}, Δy=#{result.dy}").end()
          dom.tag("li").text(if in_library then "Present in library" else "Not in library").end();
          dom.end()
          root.innerHTML = ""
          root.appendChild dom.finalize()
          @buffer.set(result.cells ? cells)
          E("analysis-result-close").focus()
        ),1 #Fast timeout
        
        
      analysisResultToLibrary: ->
        if @analysis_result?
          @library.put @analysis_result, @rule
          
      copyToBuffer: ->
        @analysis_result = null
        @buffer.set Cells.normalize @getSelectedCells()
        
      getSelectedCells: ->
        sel = @selection
        return [] unless sel
        sel = @gol.snap_box sel
        @gol.field.get_cells sel ...
        
      saveLibrary:
        unless Storage?
          -> alert "Storage not supported"
        else
          (newName=false) ->
            try
              @library.save localStorage, newName
              @updateLibrariesList()
            catch e then alert e
            
      deleteCurrentLibrary:
        unless Storage?
          -> alert "Storage not supported"
        else
          ->
            if confirm "Are you sure you want to clear current library and remove it from the local storage?\nThis action can not be undone."
              @library.deleteCurrent localStorage
              @updateLibrariesList()
      updateLibrariesList: ->
        return unless Storage?
        libsElem = E "list-libraries"
        libs=[]
        for key of localStorage
          if key.match /^library-/
            libs.push key.substr 8 #truncate "library-"
        libs.sort()
        
        libsElem.innerHTML = ""
        libsElem.options.add new Option "---", ""
        for libName in libs
          libsElem.options.add new Option libName, libName
        libsElem.options[0].selected = true
          
      showOverlay: (visible) ->
        @canvas_overlay.style.visibility = if visible then "visible" else "hidden"

  class BaseMouseTool
    constructor: (@golApp, @snapping=false, @show_overlay=true) ->
      @dragging = false
      @last_xy = null
      @old_rect = null
      
    get_xy: (e, snap=false) ->
      [x,y] = getCanvasCursorPosition(e, @golApp.canvas_container)
      ixy = @golApp.view.xy2index x, y
      if snap
        @snap_below ixy
      else
        ixy
        
    clear_old_rect: (ctx)->
      if (r = @old_rect)
        ctx.clearRect r ...
        
    snap_below: ([x,y]) ->
      gol = @golApp.gol
      [gol.snap_below(x), gol.snap_below(y)]
      
    on_mouse_up: (e) ->
      @dragging = false
      
    on_mouse_move: (e) ->
      xy = @get_xy e, @snapping
      xy0 = @last_xy
      if xy0 is null
        @last_xy = xy
      else
        unless Point.equal xy, xy0
          @on_cell_change e, xy
          @last_xy = xy

    getOverlayContext: -> @golApp.canvas_overlay.getContext("2d")
    on_mouse_down: (e) ->
      @dragging = true
      @last_xy = xy = @get_xy e, @snapping
      @on_click_cell e, xy
      
    on_enable: ->
      @dragging = false
      @last_xy = null
      if @show_overlay then @golApp.showOverlay true
        
    on_disable: ->
      if @show_overlay
        @clear_old_rect @getOverlayContext()
        @golApp.showOverlay false
        

    on_cell_change: ->
    on_click_cell: ->
    on_mouse_out: ->
      
    on_touch_start: (e)->
      if e.touches.length is 1
        @on_mouse_down(e)
        e.preventDefault()
        
    on_touch_leave: (e)->
      @on_mouse_out(e)
      
    on_touch_end: (e)->
      if @dragging
        e.preventDefault()
        @on_mouse_up(e)
        
    on_touch_move: (e)->
      if @dragging
        e.preventDefault()
        @on_mouse_move(e)

  ###
  # In some mobile browsers, ghost clicks can not be prevented. So here easy solution: every mouse event,
  # coming after some interval after a touch event is ghost
  ###
  class GhostClickDetector
    constructor: ->
      @isGhost = false
      @timerHandle = null
      @ghostInterval = 1000 #ms
      #Bound functions
      @_onTimer = =>
        @isGhost=false
        @timerHandle=null
      @_onTouch = =>
        @onTouch()

    onTouch: ->
      @stopTimer()
      @isGhost = true
      @timerHandle = window.setTimeout @_onTimer, @ghostInterval
      
    stopTimer: ->
      if (handle = @timerHandle)
        window.clearTimeout handle
        @timerHandle = null

    addListeners: (element)->
      for evtName in ["touchstart", "touchend"]
        element.addEventListener evtName, @_onTouch, false
        
  ###
  # Mouse tool for erasing
  ###
  class ToolEraser extends BaseMouseTool
    constructor: (golApp, @size=3) ->
      super golApp, false, true #no snapping, show overlay
      @preview_color = "rgba(255,20,0,0.4)"

    _drawPreview: ([x0,y0])->
      cell_size = @golApp.view.cell_size
      sz = @size*cell_size  #Size of an erased block
      dc = (@size/2)|0
      ctx = @getOverlayContext()
      ctx.fillStyle = @preview_color
      @clear_old_rect ctx
      rect = [(x0-dc)*cell_size, (y0-dc)*cell_size, sz, sz]
      ctx.fillRect rect ...
      @old_rect = rect
      null
          
    on_cell_change: (e, xy) ->
      @_drawPreview xy
      if @dragging
        @_erase_at xy
        
    _erase_at: ([x,y]) ->
      s = @size
      dc = (s/2)|0
      @golApp.gol.field.fill_box x-dc, y-dc, x-dc+s, y-dc+s, 0
      @golApp.updateCanvasBox x-dc, y-dc, x-dc+s, y-dc+s
      
    on_click_cell: (e, xy) -> @_erase_at xy
  ###
  #Mouse tool that draws given pattern
  ###
  class ToolStamp extends BaseMouseTool
    constructor: (golApp) ->
      super golApp, true, true #snapping, show overlay
      @preview_color = "rgba(255,255,0,0.4)"

    _drawPreview: ([x0,y0])->
      fig = @golApp.buffer.pattern
      return if fig.length is 0
      size = @golApp.view.cell_size
      [dx,dy]=@golApp.buffer.patternExtent
      x0-=dx
      y0-=dy
      ctx = @getOverlayContext()
      ctx.fillStyle = @preview_color
      @clear_old_rect ctx
      for [x,y], i in fig
        xx = (x+x0)*size
        yy = (y+y0)*size
        ctx.fillRect xx, yy, size, size
      @old_rect = [x0*size, y0*size, (dx+1)*size, (dy+1)*size]
      null
      
    on_cell_change: (e, xy) -> @_drawPreview xy

    on_click_cell: (e, xy) ->
      app = @golApp
      buffer = app.buffer
      extent = buffer.patternExtent
      origin = Point.subtract xy, extent
      app.gol.field.put_cells buffer.pattern, origin ...
      app.updateCanvasBox origin[0], origin[1], xy[0]+1, xy[1]+1
    
  ###
  Mouse tool that draws lines of 1 or 0 cells
  ###
  class ToolDraw extends BaseMouseTool
    constructor: (golApp) ->
      super golApp, false, false #no snapping, no overlay
      @dragging = false
      @value = null

    update_box: (xy_a, xy_b) ->
      @golApp.updateCanvasBox Point.boundBox(xy_a, xy_b) ...

    draw_at: (x, y) -> @golApp.gol.field.set x, y, @value

    on_cell_change: (e, xy) ->
      if @dragging
        dxy = Point.subtract xy, @last_xy
        [xx,yy] = line_pixels dxy ...
        [x0, y0] = last_xy = @last_xy
        for i in [1 ... xx.length]
          @draw_at x0 + xx[i], y0 + yy[i]
        @update_box last_xy, xy

    on_click_cell: (e, xy) ->
      [x,y] = xy
      @value = 1 ^ @golApp.gol.field.get(x,y)
      @draw_at x, y
      @golApp.updateCanvasBox x,y,x+1,y+1
    on_mouse_out: (e) ->
      @dragging=false

  ###
  Mouse tool that selects areas of the field
  ###
  class ToolSelect extends BaseMouseTool
    constructor: (golApp) ->
      super golApp, true, true #snapping, show overlay
      @selection_color = "rgba(0,0,255,0.3)"
      @xy0 = null
      @xy1 = null

    on_mouse_up: (e) ->
      super e
      @golApp.selection = @selection()
    
    on_cell_change: (e, xy) ->
      if @dragging
        @xy1 = xy
        @draw_box()

    on_click_cell: (e, xy) ->
      @xy0 = @xy1 = xy
      @draw_box()

    selection: ->
      if @xy0 and @xy1
        [x0,y0,x1,y1] = Point.boundBox @xy0, @xy1
        d = if @snapping then 1 else 0
        return [x0,y0,x1+d, y1+d]
      else
        return [0, 0, 0, 0]

    draw_box: ->
      ctx = @getOverlayContext()
      size = @golApp.view.cell_size
      ctx.fillStyle = @selection_color
      [x0,y0,x1,y1] = @selection()
      rect = [x0 * size, y0 * size, (x1 - x0) * size, (y1-y0) * size]
      @clear_old_rect ctx
      @old_rect = rect
      ctx.fillRect rect ...

  #////////////////////////////
  # Buffer pane
  #////////////////////////////
  class BufferPane
    constructor: (@canvas, pattern=[], @desiredSize=[64, 64]) ->
      throw new Error "Not a canvas" unless @canvas.getContext?
      @_bindEvents()
      @oldRleValue = null
      @set pattern
    #Update image of the current pattern
    updatePattern: ->
      canv = @canvas
      getCanvas = (w, h)->
        canv.width = w
        canv.height = h
        return canv
      canv = drawPatternOnCanvas getCanvas, @pattern, @desiredSize, [1, 24], 1
    
    #Set and show current pattern
    set: (pattern, update_rle=true)->
      @pattern = pattern
      [ex, ey] = Cells.extent pattern
      @patternExtent = [ex+(ex&1), ey+(ey&1)]
      @updatePattern()
      @toRle() if update_rle

    #Rotate or flip current pattern
    transform: (tfm) -> @set Cells.transform @pattern, tfm
    togglePhase: -> @set Cells.togglePhase @pattern
    toRle: -> E("rle-encoded").value = @oldRleValue = Cells.to_rle @pattern
    fromRle: ->
      messageElt = E("rle-decode-message")
      messageBoxElt = E("rle-decode-box")
      rle = remove_whitespaces E("rle-encoded").value
      if rle isnt @oldRleValue
        @oldRleValue = rle
        try
          @set (Cells.from_rle rle), false
          messageBoxElt.style.visibility = "hidden"
          messageElt.innerHTML = ""
        catch e
          messageElt.innerHTML = ""+e
          messageBoxElt.style.visibility = "visible"
    _bindEvents: ->
      addDelayedListener E("rle-encoded"), ["keypress", "blur", "change"], 200, => @fromRle()

  fill_rules = (select, predefined_rules) ->
    opts = select.options
    for [name, rule], i in predefined_rules
      opts[i] = new Option(name, rule.stringify())
    opts[opts.length] = new Option("(User Defined)", "")
    
  #//////////////////////////////////////////////////////////////////////////////
  # Rule analysis
  #//////////////////////////////////////////////////////////////////////////////
  cells_icon = (value) -> "cellicon icon-cells_#{ value.toString(16) }"
  show_rule_diagram = (ruleObj, element) ->
      #rule must be array of 1 6 integers
      
      dom = new DomBuilder
      
      elements = [[("0000"), ("1111")],
        [("1000"), ("0100"), ("0001"), ("0010")],
        [("1100"), ("0101"), ("0011"), ("1010")],
        [("1001"), ("0110")],
        [("0111"), ("1011"), ("1110"), ("1101")]]

      ruleObj.validate()
      dom.tag("table").CLASS("library-table")
         .tag("thead")
         .tag("tr").tag("th").text("Phase").end().tag("th").text("Diagram").end()
         .end().end()
         .tag("tbody")
        
      for elemRule, i in ruleObj.rules
        dom.tag("tr").tag("td").text(i+1).end().tag("tr")
        rule = elemRule.table
        for row in elements
          dom.tag("div").CLASS("func_row")
          isFirst = true
          for x_str,j in row
            x_value = parseInt(x_str, 2)
            y_value = rule[x_value]
            unless y_value is x_value
              dom.tag("span").CLASS("icon icon-separator").end()  unless isFirst
              dom.tag("span").CLASS("func_pair")
                 .tag("span").CLASS(cells_icon(x_value)).end()
                 .tag("span").CLASS("icon icon-rarrow").end()
                 .tag("span").CLASS(cells_icon(y_value)).end()
                 .end() #func-pair
              isFirst = false
          dom.end() #div
        dom.end().end() #td/tr
      dom.end().end() #tbody/table
      element.innerHTML = ""
      element.appendChild dom.finalize()

  show_rule_properties = (rule, element) ->
    ######## Analysis part #########

    symmetries = rule.find_symmetries()
    population_invariance = rule.invariance_type()
    invertible = rule.is_invertible()
    dualTransform = getDualTransform rule
    vacuum_cycle =  rule.vacuum_cycle()
    ######### Report generatio part ############
    dom = new DomBuilder

    dom.tag("p").text("Rule is ").tag("span")
       .CLASS(if invertible then "green-text" else "red-text")
       .text(if invertible then "invertible" else "non-invertible")
       .end().text(". ")
      
    dom.text("Population is ").text(
      switch population_invariance
        when "const" then "constant"
        when "inv-const" then "constant with inverse"
        else "variable"
    ).text(".")
    dom.end()
      
    dom.tag("p").text("Rule is invariant to:").tag("ul")
    hasAny = false
    for symm of symmetries
      dom.tag("li").text(Transforms.getDescription(symm)).end()
      hasAny = true
    unless hasAny
      dom.tag("li").text("Nothing").end()
    dom.end().end() #/ul /p
    
    dom.tag "p"
    if dualTransform[0] is null
      dom.text "Rule has no dual transform."
    else
      if dualTransform[0] is "iden"
        dom.text "Rule is self-dual"
      else
        dom.text("Rule has dual transform: ").text(Transforms.getDescription dualTransform[0])
    dom.end()


    if invertible
      dom.tag "p"
      if rule.is_vacuum_stable()
        dom.text "Rule has stable vacuum."
      else
        dom.text "Rule has periodic vacuum with period #{vacuum_cycle.length}. The period is:"
        dom.tag("div").CLASS("func_row").tag("span").CLASS("func_pair")
        for value, i in vacuum_cycle
          dom.tag("span").CLASS("icon icon-rarrow").end() if i
          dom.tag("span").CLASS(cells_icon(value)).end()
        dom.end().end()
      dom.end()
  
    
    element.innerHTML = ""
    element.appendChild dom.finalize()

  Transforms =
    iden:  "identity transform"
    rot90:  "rotation by 90°"
    rot180:  "rotation by 180°"
    rot270:  "rotation by 270°"
    flipx:  "horizontal flip"
    flipy:  "vertical flip"
    flipxy:  "flip across main diagonal"
    flipixy:  "flip across anti-diagonal"
    negate: "negation of cells"
    flipx_neg: "horizontal flip with negation"
    flipy_neg: "vertical flip with negation"

    getDescription: (name)->
      if (txt=this[name])?
        txt
      else
        throw new Error "Unknown identity transform name: #{name}"
    
  #Function for drawing a single pattern on a canvas
  #Arguemnts:
  # canvasGetter: (w, h) -> canvas   Return Canvas instance, taking in account given width and height.
  drawPatternOnCanvas = (canvasGetter, cells, desired_size, cell_size_limits, grid_width) ->
        [DESIRED_W, DESIRED_H] = desired_size
        [cell_min, cell_max] = cell_size_limits
        [x0, y0, cols, rows] = Cells.bounds cells
        cols++
        rows++
        cols += (cols % 2)
        rows += (rows % 2)
        
        cellSize = cap cell_min, cell_max, Math.min( DESIRED_W/cols, DESIRED_H/rows) |0
        if cellSize <= 2 then grid_width = 0

        fld = new Array2d cols, rows
        fld.fill 0
        fld.put_cells cells, 0, 0
        view = new FieldView fld
        view.cell_size = cellSize
        view.grid_width = grid_width
        
        canv = canvasGetter cols * cellSize, rows * cellSize
        ctx = canv.getContext "2d"
        view.draw ctx
        return canv

  class LibraryPane
    constructor: (@div, @librarySizeElement, @golApp)->
      @key2result = {}
      @librarySize = 0
      @desired_size = [80,40] #Try to adjust box to this size
      @_createTable()
      @name = ""
      @modified = false
      @updateLibrarySize()
      @updateLibraryName()

    _createTable: ->
      dom = new DomBuilder "table"
      dom.a("class", "library-table")
         .tag("thead").tag("tr")
      for hdr in ["Pattern", "Population", "Period", "Offset", "V", "RLE", "Count", ""]
        dom.tag("th").text(hdr).end()
      dom.end().end() #/tr/th
         .tag("tbody").store("library_body")
      {@library_body} = dom.vars
      @div.appendChild dom.finalize()
      
    put: (result, rule)->
      return unless result?
      rle = Cells.to_rle result.cells

      unless rle of @key2result
        if result.dx!=0 or result.dy!=0
          [dual_pattern, dx1, dy1] = Cells.getDualSpaceship result.cells, rule, result.dx, result.dy
          if dual_pattern?
            dual_rle = Cells.to_rle dual_pattern
            if dual_rle of @key2result
              result.cells = dual_pattern
              result.dx = dx1
              result.dy = dy1
              rle = dual_rle
              
      record = (
          result: result
          count: 1
          counter: null #DOM element, containing items count
          key: rle
      )
      @_putRecord record
      @updateLibrarySize()
      
    defaultLibraryForRule: (rule) ->
      sRule =  rule.stringify()
      Rule2Name[ rule.stringify() ] ? "Default:[#{sRule}]"
      
    #True, if the library already have this analysis result
    has: (result)->
      rle = Cells.to_rle result.cells
      return (rle of @key2result)
      
    hasDual: (result, rule)->
      if result.dx?
        [dual_pattern, dx1, dy1] = Cells.getDualSpaceship result.cells, rule, result.dx, result.dy
        if dual_pattern?
          (Cells.to_rle dual_pattern) of @key2result
      false
      
    _putRecord: (record)->
      old_record = @key2result[record.key]
      @modified = true
      if old_record?
        old_record.count += record.count
        @updateRecord old_record
      else
        @key2result[record.key] = record
        @addRecord record
        @librarySize += 1
        
    updateLibrarySize: ->
      @librarySizeElement.innerHTML = "" + @librarySize
      E("library-modified-elem").style.visibility =
        if @modified then "visible" else "hidden"
    
    updateLibraryName: ->  
      E("library-name").innerHTML = ""
      name = @name or "[New Library]"
      E("library-name").appendChild document.createTextNode name
      
    updateRecord: (record)->
      record.counter.innerHTML = ""+record.count
      
    copyRecord: (rec)->
      result: rec.result
      count: rec.count
      key: rec.key

    dumpToStorage: (storage, name)->
      throw new Error "No storage" unless storage?
      storage[name] =  @data2string()
      @name = name
      @modified = false
      
    data2string: ->
      s = (@copyRecord @key2result[key] for key of @key2result)
      JSON.stringify s

    showStoredData: ->
      E("library-json-data").value = @data2string()
      
    importData: ->
      try
        elt = E("library-json-data")
        @_importData JSON.parse elt.value
        elt.value = ""
      catch e
        alert "Failed to import JSON: "+e
        
    clear: ->
      @key2result = {}
      @librarySize = 0
      @library_body.innerHTML=""
      @modified = false
      @name = ""
      @updateLibrarySize()
      @updateLibraryName()
      
    _importData: (stored) ->
      for rec in stored
        rec.counter = null
        if rec.key not in @key2result
          @_putRecord rec
      @updateLibrarySize()
      null
    _libraryKey: (name) -> "library-"+name
    
    load: (storage, name) ->
      unless (@_libraryKey name) of storage
        alert "Library \"#{name}\" is not present in the storage."
        return
      if @modified
        unless confirm "Current library has unsaved modifications. Do you want to discard them?"
          return
      @clear()
      @name = name
      @_importData JSON.parse storage[ @_libraryKey name]
      @modified = false
      @updateLibrarySize()
      @updateLibraryName()

    save: (storage, newName=false)->
      if (not newName) and (not @modified)
        return
      name=@name
      if newName or (name is "")
        name = prompt "Please enter library name", @defaultLibraryForRule @golApp.rule
        if not name then return
        if (@_libraryKey name) of storage
          unless confirm "Library #{name} already exists in the storage. Do you want to overwrite it?"
            return
        @name = name
        @updateLibraryName()
      storage[@_libraryKey name] = @data2string()
      @modified = false
      @updateLibrarySize()
    deleteCurrent: (storage)->
      unless @name
        alert "Library is not saved"
        return
      delete storage[@_libraryKey @name]
      @clear()
      
    addRecord: (record)->
        result = record.result
        
        makeCanvas = (imgW, imgH) -> makeElement "canvas", [["width", imgW], ["height", imgH]]
        
        canv = drawPatternOnCanvas makeCanvas, result.cells, @desired_size, [1, 24], 1
        #if canv.toDataURL? #Convert to static image, is supported
        #  canv = makeElement "img", [["src", canv.toDataURL()]]
        v_str =
          if result.period?
            rational2str Math.max(Math.abs(result.dx), Math.abs(result.dy)), result.period
          else
            "?"

        #["Pattern", "Pop", "Per", "dX", "V", "RLE", "CNt", "Close"]
        dom = new DomBuilder "tr"
        dom.CLASS("pattern-report")
          .tag("td").tag("div").CLASS("lib-pattern-background")
            .tag("a").store("aSelect").a("href","#").a("title", "Click to select pattern")
              .append(canv)                                        #image
          .end().end().end()
          .tag("td").text(result.cells.length).end()              #population
          .tag("td").text(result.period ? "?").end()                    #period 
          .tag("td").text("(#{ result.dx ? "?" },#{ result.dy ? "?"})").end() #dx
          .tag("td").text(v_str).end()                             #V
          .tag("td").tag("div").CLASS("rle-box").text(Cells.to_rle(result.cells)).end().end()        #rle
          .tag("td").store("cnt").text(record.count).end()      #counter
          .tag("td").tag("a").a("href","#").CLASS("button").store("closebtn")
            .tag("span").CLASS("icon icon-clearall").a("title", "Remove record")
              .text("X")
            .end()
          .end().end()
        #Table row DOM is built, now attach event listeners
        record.counter = dom.vars.cnt
        dom.vars.closebtn.addEventListener "click", (e) =>
          @._removeItem record.key
          e.preventDefault()

        dom.vars.aSelect.addEventListener "click", (e)=>
          @golApp.buffer.set result.cells
          
        #Insert new row before the end
        @library_body.insertBefore (record.element = dom.finalize()), null 
        
    _removeItem: (key) ->
      record = @key2result[key]
      delete @key2result[key]
      record.element.parentNode.removeChild record.element
      @librarySize -= 1
      @modified = true
      @updateLibrarySize()

    ##Filter library by a predicate, that takes "result": object, returned by the analysis function
    filter: (predicate) ->
      to_remove = []
      for key of @key2result
        unless predicate @key2result[key]
          to_remove.push key
      for key in to_remove
        @_removeItem key
        
  #//////////////////////////////////////////////////////////////////////////////
  # Spaceship catcher
  #//////////////////////////////////////////////////////////////////////////////
  class SpaceshipCatcher
    constructor: (@on_pattern, @max_size=20, @reseed_period=300000) ->
      @search_area=1
      @spaceships_found = []
      @search_radius = 4
      
    #Scan field for the spaceships; remove them from the field
    scan: (gol)->
      f = gol.field
      pick = (x,y) =>
        x0 = gol.snap_below x
        y0 = gol.snap_below y
        fig = f.pick_pattern_at x, y, x0, y0, true, @search_radius, @max_size #pick and erase
        if fig.length < @max_size
          @on_pattern fig
      for y in [0...@search_area] by 1
        for x in [0...f.width] by 1
          if f.get(x,y) isnt 0 then pick x, y
      for y in [@search_area ... f.height] by 1
        for x in [0...@search_area] by 1
          if f.get(x,y) isnt 0 then pick x, y
      null
        

  loadExternalCSS = (cssHref) ->
    link = document.createElement "link"
    link.rel = "stylesheet"
    link.type = "text/css"
    link.href = cssHref
    document.getElementsByTagName("head")[0].appendChild link
    
  # Bind appliction to GUI
  (->
  #//////////////////////////////////////////////////////////////////////////////
  # Initialization block
  #//////////////////////////////////////////////////////////////////////////////
    unless document.implementation.hasFeature "http://www.w3.org/TR/SVG11/feature#Image", "1.1"
      loadExternalCSS "icons-png.css"
    golApp = new GolApplication([64, 64], "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15", "overlay-container", "canvas", "overlay", "time")
    
    fastButton = (id, handler) ->
      e = E id
      e.addEventListener "click", (e)->
        e.preventDefault()
        unless golApp.ghost_click_detector.isGhost
          handler e
      e.addEventListener "touchstart", (e)->
        e.preventDefault()
        golApp.ghost_click_detector.onTouch()
        handler e

    fill_rules E("select-rule"), predefinedRules

    
    fastButton "clear_field", -> golApp.do_clear()
    fastButton "go-next", -> golApp.doStep()
    fastButton "go-back", -> golApp.doReverseStep()
    fastButton "rplay", -> golApp.startPlayer -1
    fastButton "play", -> golApp.startPlayer 1
    fastButton "stop", -> golApp.stopPlayer()
    E("reset-timer").onclick = -> golApp.reset_time()
    E("nullify-phase").onclick = -> golApp.nullifyRulesetPhase()

    #RUle set from the editor
    E("select-style").onchange = ->
      sz = parseInt E("select-style").value, 10
      golApp.setCellSize sz


    fastButton "clear-selection", -> golApp.clear_selection()
    fastButton "clear-nonselection", -> golApp.clear_nonselection()
    fastButton "selection-random", -> golApp.random_fill_selection (parseFloat(E("random-fill-percent").value)*0.01)
    fastButton "selection-analyze", -> golApp.analyzeSelection()

     
    E("speed-show-every").onchange = ->
      golApp.step_size = parseInt(E("speed-show-every").value)

    E("speed-frame-delay").onchange = (e) ->
      golApp.setDelay parseInt(E("speed-frame-delay").value)

    E("select-rule").onchange = ->
      if (rule = E("select-rule").value) isnt ""
        golApp.set_rule_str rule
        

    E("show-grid").onchange = -> golApp.setShowGrid E("show-grid").checked
    E("stablize-rule").onchange = ->      
      golApp.enableRuleset E("stablize-rule").checked


    btnGroupTools= new ButtonGroup E("btn-group-tools"), "a", "btn-tool-draw"
    btnGroupTools.addEventListener "change", (e, id)->
      tool = switch id
        when "btn-tool-draw" then "draw"
        when "btn-tool-select" then "select"
        when "btn-tool-stamp" then "stamp"
        when "btn-tool-erase" then "eraser"
      e.preventDefault()
      golApp.setMouseTool golApp.mouse_tools[tool]


    btnGroupFeatures= new ButtonGroup E("btn-group-features"), "a", "feature-rule-details"
    button2panel = {
        "feature-rule-details":"rule-info-pane"
        "feature-gif-recorder":"gif-recorder-pane"
        "feature-library":"library-pane"
        "feature-settings":"settings-pane"
    }
    #Hide all panels except the selected one
    for btnId, panelId of button2panel
      if btnId isnt "feature-rule-details"
        E(panelId).style.display = "none"
    btnGroupFeatures.addEventListener "change", (e,id, oldId) ->
      if oldId isnt null then E(button2panel[oldId]).style.display = "none"
      E(button2panel[id]).style.display = "block"
      e.preventDefault()
    

    E("gif-start").onclick = nodefault -> golApp.start_gif_recorder()
    E("gif-stop").onclick = nodefault ->  golApp.stopGifRecorder true
    E("gif-clear").onclick = nodefault -> golApp.gifRecorderClear()

    E("lib-save").onclick = -> golApp.saveLibrary(false)
    E("lib-save-as").onclick = -> golApp.saveLibrary(true)
    E("lib-export-json").onclick = -> golApp.library.showStoredData()
    E("lib-import-json").onclick = -> golApp.library.importData()
    E("lib-new").onclick = -> golApp.library.clear()
    E("lib-erase").onclick = -> golApp.deleteCurrentLibrary()
    E("list-libraries").onchange = ->
      libName = E("list-libraries").value
      if libName
        try
          golApp.library.load localStorage, libName
        catch e
          alert e
    E("lib-remove-composites").onclick = ->
      isnt_composite = (record) ->
        groups = splitPattern(golApp.rule, record.result.cells, record.result.period)
        groups.length <= 1
      try
        golApp.library.filter isnt_composite
      catch e
        alert "Error:"+e
    E("lib-load-default").onclick = ->
      golApp.library.load localStorage, golApp.library.defaultLibraryForRule golApp.rule

    E("select-size").onchange = ->
      try
        [cols, rows] = JSON.parse E("select-size").value
        golApp.setSize cols, rows
        #Cell  size might have been changed - update it
        selectOrAddOption E("select-style"), golApp.view.cell_size
      catch e
        null
    fastButton "toggle-catcher", ->
      if golApp.spaceship_catcher isnt null
        golApp.disable_spaceship_catcher()
      else
        golApp.enable_spaceship_catcher()
        

    E("library-json-data").onfocus = E("rle-encoded").onfocus = ->
      window.setTimeout (=>@select()), 100


    E("analysis-result-to-library").onclick = -> golApp.analysisResultToLibrary()
    E("analysis-result-close").onclick= ->
    E("analysis-result").onclick = E("analysis-result-close").onclick = ->
      E("analysis-result").style.display="none"

    fastButton "pattern-rotate-cw", -> golApp.buffer.transform [0,-1,1,0]
    fastButton "pattern-rotate-ccw", -> golApp.buffer.transform [0,1,-1,0]
    fastButton "pattern-flip-h", -> golApp.buffer.transform [-1,0,0,1]
    fastButton "pattern-flip-v", -> golApp.buffer.transform [1,0,0,-1]
    fastButton "pattern-toggle-phase", -> golApp.buffer.togglePhase()
    fastButton "pattern-from-selection", -> golApp.copyToBuffer()

    E("app-create-link").onclick = -> E("url-output").value = golApp.encode_state_in_url()
    E("url-output").onfocus = ->
      window.setTimeout (=>@select()), 100

    #Applicaiton initialization
    golApp.step_size = parseInt E("speed-show-every").value
    golApp.step_delay = parseInt E("speed-frame-delay").value
    
    golApp.initialize()

    
  )()
