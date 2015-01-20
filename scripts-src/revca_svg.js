function startup(evt){
    "use strict";
    var svgns = "http://www.w3.org/2000/svg";
    var xlinkns = "http://www.w3.org/1999/xlink";
    var doc = evt.target.ownerDocument;
    var svgroot = doc.rootElement;

    var palette = ["rgb(255,224,131)",
		   "rgb(135,195,248)",
		   "rgb(244,136,136)",
		   "rgb(199,133,220)",
		   "rgb(140,140,140)",
	           "rgb(190,190,121)",
		   "rgb(255,250,250)",
		   "rgb(115,115,255)",
		   "rgb(100,255,100)",
		   "rgb(129,195,159)"];

    (function(){
	var noscript = doc.getElementById("no-script");
	noscript.parentNode.removeChild(noscript);
    })();


    var parse_rle = function(rle_string) {
	//copipe from the compiled coffee code
	var c, count, curCount, i, j, x, y, _i, _j, _ref;
	var cells = [];
	x = 0;
	y = 0;
	curCount = 0;
	for (i = _i = 0, _ref = rle_string.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
	    c = rle_string.charAt(i);
	    if (("0" <= c && c <= "9")) {
		curCount = curCount * 10 + parseInt(c, 10);
	    } else {
		count = Math.max(curCount, 1);
		curCount = 0;
		switch (c) {
		case "b":
		    x += count;
		    break;
		case "$":
		    y += count;
		    x = 0;
		    break;
		case "o":
		    for (j = _j = 0; _j < count; j = _j += 1) {
			cells.push([x, y]);
			x += 1;
		    }
		    break;
		default:
		    throw new Error("RLE: unexpected character '" + c + "' at position " + i);
		}
	    }
	}
	return cells;
    };

    var filterTrue=function(blk){
	var rval = [];
	for( var i=0, n=blk.length; i!=n; ++i){
	    var item = blk[i];
	    if (item) rval.push(item);
	};
	return rval;
    };

    var createUse=function( id ){
	var use = doc.createElementNS(svgns, "use");
	use.setAttributeNS(xlinkns, "href", "#"+id);
	return use;
    };

    var count=function(blk){
	var c = 0;
	for(var i=0; i<blk.length; ++i){ if (blk[i]) c++; };
	return c;
    };
    /// Represents grouped objects. 
    var Group = function( root, x0, y0, cells){
	this.cells = cells;
	// g - outer (offset)
	//   g - group (inner)
	//      use - background
	//      g - un-offset cells
	//         cell1, cell2 , ...
	var g_offset = doc.createElementNS(svgns, "g");
	queryFirstTfm(g_offset).setTranslate(x0,y0);
	var g_block = doc.createElementNS(svgns, "g");
	var g_unoffset = doc.createElementNS(svgns, "g");
	queryFirstTfm(g_unoffset).setTranslate(-x0,-y0);
	for( var i=0, _i=cells.length; i!=_i; ++i){
	    root.removeChild(cells[i]);
	    g_unoffset.appendChild(cells[i]);
	};
	g_offset.appendChild(g_block);
	g_block.appendChild(g_unoffset);
	root.appendChild(g_offset);
	this.inner = g_block;
	this.outer = g_offset;
	return this;
    };

    Group.prototype.explode=function( ){
	var root = this.outer.parentNode;
	for( var i=0, _i=this.cells.length; i!=_i; ++i){
	    var ci = this.cells[i];
	    ci.parentNode.removeChild(ci);
	    root.appendChild(ci);
	};
	root.removeChild(this.outer);
	return this.cells;
    };

    var Field=function( rootElem, w, h, x0, y0, cells ){
	this.size = 20;
	this.root = rootElem;
	this.width = w; 
	this.height=h;
	this.refElemId = "cell-image";
	this.blockElemId = "block";
	this.phase = 1;
	this.groups = [];
	var data = this.data = [];
	for( var y=0;y<h;++y){
	    var row = data[y] = [];
	    for( var x=0; x<w; ++x ){
		row[x] = null;
	    }
	}
	this.createGrids();

	for(var i=0, n=cells.length; i<n; ++i){
	    var xy=cells[i];
	    this.setCell(x0+xy[0]+1,y0+xy[1]+1, palette[i%palette.length]);
	}
    };
    Field.prototype.createGrids = function(){
	var grid = doc.getElementById("grid");
	var grids = [doc.createElementNS(svgns, "g"),
		     doc.createElementNS(svgns, "g") ];
	
	grid.appendChild(grids[0]);
	grid.appendChild(grids[1]);

	var sz = this.size;
	//vertivcal lines
	for( var x = 1; x < this.width-2; ++x ){
	    var line = doc.createElementNS(svgns, "line");
	    line.setAttribute("x1", x*sz);
	    line.setAttribute("y1", 0);
	    line.setAttribute("x2", x*sz);
	    line.setAttribute("y2", (this.height-1)*sz);
	    grids[(x+1) % 2].appendChild(line);
	};
	//horizontal lines
	for( var y = 1; y < this.height-2; ++y ){
	    var line = doc.createElementNS(svgns, "line");
	    line.setAttribute("x1", 0);
	    line.setAttribute("y1", y*sz);
	    line.setAttribute("x2", (this.width-2)*sz);
	    line.setAttribute("y2", y*sz);
	    grids[(y+1) % 2].appendChild(line);
	};
	this.grids = grids;
	grids[0].style.opacity = 1;
	grids[1].style.opacity = 0;
	return grid;
    };

    Field.prototype.get=function(x,y){
	return this.data[y][x];
    };

    Field.prototype.set = function(ix,iy,v){
	this.data[ iy ][ ix ]=v;
	if (v){
	    var sz = this.size;
	    queryFirstTfm(v).setTranslate(ix*sz, iy*sz);
	}
    };

    Field.prototype.setCell=function(x,y,color){
	var c = this.get(x,y)
	if( !c ){
	    c = createUse(this.refElemId);
	    if (color)
		c.setAttribute("fill", color);
	    this.set(x,y,c);
	    this.root.appendChild(c);
	}
	return c;
    };

    Field.prototype.animateAppearGrid = function(t){
	var op = t*0.7 + 0.15;
	this.grids[this.phase    ].style.opacity = op;
	this.grids[this.phase ^ 1].style.opacity = 1-op;
    };
    Field.prototype.block=function(x,y){
	return [this.get(x,y), this.get(x+1,y), this.get(x,y+1), this.get(x+1,y+1)]
    };
    Field.prototype.groupBlocks = function(){
	var x, y, sz=this.size, ph = this.phase, w=this.width, h=this.height;
	for( y=ph; y < h-ph; y+=2){
	    for (x=ph; x < w-ph; x+=2){
		var b = this.block(x,y);
		if (count(b) === 1){
		    var grp = this.groupBlock(x*sz+sz,y*sz+sz,b);
		    grp.index = [x,y];
		}
	    };
	};
	this.phase = ph ^ 1;
    };
    //Update border cells so that they will wrap around.
    Field.prototype.wrapBorderCells = function(){
	var x,y,w=this.width, h=this.height;
	for(x=1;x<w;++x){
	    // (x_src,y_src )  -> (x_dst, y_dst)
	    this.copyCell( x, h-2, x, 0 );
	    this.copyCell( x, 1, x, h-1 );
	};
	for(y=1;y<h;++y){
	    // (x_src,y_src )  -> (x_dst, y_dst)
	    this.copyCell( w-2, y, 0,  y );
	    this.copyCell( 1, y, w-1,  y );
	};
	this.copyCell( 1, 1, w-1, h-1);
	this.copyCell( w-2, 1, 0, h-1);
	this.copyCell( 1, h-2, w-1, 0);
	this.copyCell( w-2, h-2, 0, 0);
    };
    Field.prototype.copyCell = function(xSrc, ySrc, xDst, yDst){
	var src = this.get(xSrc, ySrc);
	var oldDst = this.get(xDst, yDst);
	if (oldDst) oldDst.parentNode.removeChild(oldDst);
	if (src){
	    var dst = createUse(this.refElemId);
	    this.set(xDst, yDst, dst);
	    var v = src.getAttribute("fill");
	    if (v) dst.setAttribute("fill", v);
	    this.root.appendChild(dst);
	}else{
	    this.set(xDst, yDst, null);
	}
    };
    Field.prototype.groupBlock = function( x0, y0, blk ){
	//1. remove cells from the XML
	//2. Create group with background
	//3. Offset cells
	//4. Add cells to the group
	//5. Add group to the field.
	var grp = new Group( this.root, x0, y0, filterTrue(blk) );
	grp.block = blk;
	grp.background = createUse(this.blockElemId);
	grp.inner.insertBefore(grp.background, grp.inner.firstChild);
	this.groups.push(grp);
	return grp;
    };

    Field.prototype.unGroupBlocks = function(){
	for(var i=0, n=this.groups.length; i!=n; ++i){
	    var grp = this.groups[i];
	    grp.explode();
	    var _gi=grp.index, ix = _gi[0], iy = _gi[1];
	    //Put rotated group contents back to the grid.
	    // 0 1  > 2 0
	    // 2 3  > 3 1
	    this.set(ix, iy, grp.block[2] );
	    this.set(ix+1, iy, grp.block[0] );
	    this.set(ix, iy+1, grp.block[3] );
	    this.set(ix+1, iy+1, grp.block[1] );
	};
	this.groups = [];
	if (this.phase === 0){
	    this.wrapBorderCells();
	}
    };


    ///Get first transform from the objects transform list; adding one is not defined.
    var queryFirstTfm = function( elem ){
	var tfms = elem.transform.baseVal;
	if (tfms.numberOfItems === 0){
	    tfms.initialize(svgroot.createSVGTransform());
	}
	return tfms.getItem(0);
    };
    Field.prototype.animateRotateGroups = function(t){
	for(var i=0, n=this.groups.length; i!=n; ++i){
	    queryFirstTfm(this.groups[i].inner).setRotate(90.0*t,0,0);
	};
    };

    Field.prototype.animateAppearGroups = function(t){
	for(var i=0, n=this.groups.length; i!=n; ++i){
	    this.groups[i].background.style.opacity = t;
	};
    };

    //Smooth curve with slow start and slow end.
    var curveSmooth = function(x){ return x*x*(3-2*x); };
    var iden = function(x){return x;};
    var reverse = function(x){return 1.0-x;};

    var AnimationStep=function(duration, object, method, timeCurve, methodBegin, methodEnd){
	this.duration = duration;
	this.object = object || null;
	this.method = method || null;
	this.methodBegin = methodBegin || null;
	this.methodEnd = methodEnd || null;
	this.timeCurve = timeCurve || iden;
    };

    AnimationStep.prototype.run = function(t){
	var m = this.method;
	if (m) m.call( this.object, this.timeCurve(t) );
    };
    AnimationStep.prototype.begin = function(){
	var m = this.methodBegin;
	if (m) m.call( this.object );
	this.run(0.0);
    }
    AnimationStep.prototype.end = function(){
	var m = this.methodEnd;
	if (m) m.call( this.object );
	this.run(1.0);
    }
    
    var Animation=function(){
	this.steps=[];
	this.curTime=0.0;
	this.curStep=0;
	this.totalDuration = 0;
    };
    Animation.prototype.addStep=function( step ){
	this.steps.push(step);
	this.totalDuration += step.duration;
    };
    Animation.prototype.animate=function(dt){
	if (this.steps.length === 0) return;
	var t = this.curTime + dt;
	while(true){
	    var step = this.steps[this.curStep];
	    if (t >= step.duration){
		//finish the animation of current step
		step.end();
		t -= step.duration;
		//move to the next step
		this.curStep = (this.curStep + 1) % this.steps.length;
		//start the next step
		this.steps[this.curStep].begin();
	    }else{
		//play pending animation
		step.run(t / step.duration);
		break;
	    }
	}
	this.curTime = t;
    };

    // playAnimationInfinite :: (callback, speed) -> void; where callback:: (double->void)
    Animation.prototype.playInfinite = (function(){
	var requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
            window.webkitRequestAnimationFrame || window.msRequestAnimationFrame;
	//Create on of 2 functions: either using requestAnimationFrame, or using usual timers
	if (requestAnimationFrame){
	    return (function(speed){
		var oldTimestamp = null, _this=this;
		var step = function(timestamp){
		    _this.animate((oldTimestamp === null) ? 0 : Math.min(1000, timestamp - oldTimestamp)*speed);
		    oldTimestamp = timestamp;
		    requestAnimationFrame(step);
		};
		if (! this.stopRequested)
		    requestAnimationFrame(step);
	    });
	}else{
	    return (function(speed){
		var dt = 40; //desired FPS is 1000/40 = 25
		var _this=this;
		window.setInterval( function(){_this.animate(dt*speed);}, dt );
	    });
	}
    })();
    var parseUri = function(str) {
	var i, m, o, uri, _ref, k, v;
	o = parseUri.options;
	m = o.parser[(o.strictMode ? "strict" : "loose")].exec(str);
	uri = {};
	i = 14;
	while (i--) {
	    uri[o.key[i]] = m[i] || "";
	}
	uri[o.q.name] = {};
	uri[o.key[12]].replace(o.q.parser, function($0, $1, $2) {
	    if ($1) {
		return uri[o.q.name][$1] = $2;
	    }
	});
	_ref = uri.queryKey;
	for (k in _ref) {
	    v = _ref[k];
	    uri.queryKey[k] = decodeURIComponent(v);
	}	
	return uri;
    };
    parseUri.options = {
	strictMode: false,
	key: ["source", "protocol", "authority", "userInfo", "user", "password", "host", "port", "relative", "path", "directory", "file", "query", "anchor"],
	q: {
	    name: "queryKey",
	    parser: /(?:^|&)([^&=]*)=?([^&]*)/g
	},
	parser: {
	    strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
	    loose: /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
	}
    };

    var showError=function(err){
	var errElem = doc.getElementById("error-box");
	var y = 0, lineLen = 20, lineHeight=16;
	while (err.length > 0){
	    var part=err.substring(0,lineLen);
	    err = err.substr(lineLen);
	    var t = doc.createElementNS(svgns, "text");
	    t.setAttribute("x", 0);
	    t.setAttribute("y", y);
	    t.appendChild(doc.createTextNode(part));
	    errElem.appendChild(t);
	    y += lineHeight;
	}
    };

    try{
	var keys = parseUri(doc.defaultView.location).queryKey;
	var rle = keys.rle || "3o$o$bo";
	var rle_x = parseInt(keys.x || "2", 10);
	var rle_y = parseInt(keys.y || "2", 10);
	var speed = parseFloat(keys.speed || "0.1");
	var quick = parseInt(keys.quick || "0", 10);

	if (keys.palette)
	    palette = keys.palette.split(";");

	var fld = new Field( doc.getElementById("field") , 22,22, rle_x, rle_y, parse_rle(rle) );
	if (quick) fld.blockElemId="block-empty"

	var anim = new Animation();

	if (! quick){
	    anim.addStep( new AnimationStep(30, fld, fld.animateAppearGrid ) );
	    anim.addStep( new AnimationStep(40) );
	}
        anim.addStep( new AnimationStep(0,  fld, null, null, fld.groupBlocks ));
	if (! quick){
	    anim.addStep( new AnimationStep(10, fld, fld.animateAppearGroups ));
	    anim.addStep( new AnimationStep(20));
	}
	anim.addStep( new AnimationStep(40, fld, fld.animateRotateGroups, curveSmooth ));
	if (! quick){
	    anim.addStep( new AnimationStep(10, fld, fld.animateAppearGroups, reverse ));
	}
	anim.addStep( new AnimationStep(0,  fld, null, null, fld.unGroupBlocks));

	anim.playInfinite( speed );
    }catch(e){
	showError(""+e);
    }
}
