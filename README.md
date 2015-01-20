js-revca
========

Reversible Cellular Automata simulator in HTML5 + Java Script.


The Simulator
=============

The Simulator is a cross-platform web (html5+js) application for exploring reversible cellular automata with Margouls neighborhood.
To start using, open the index.html file. The interface is fairly standard for the applicaitons of such kind.

See it here: http://dmishin.github.io/js-revca/index.html

Some explanations on Reversible Cellular Automata: http://dmishin.blogspot.ru/2013/10/reversible-cellular-automata.html

Features
--------

The applicaiton simulates closed thoroidal field with 2 possble cell states: ON and OFF.
Field size Is only limited by the size and performance of your computer, but 1024x1024 is close to the upper reasonable limit.
Some efforts were put into improving performance of the Simulator, allowing to simulate medium-sized fields for millions of generations in reasonable time.

Besides the basic field editing and simulation, the application offers some advanced features:

1. **Pattern analyzer**: automatically detect type (oscillator / spaceship / neither), period and canonical form of the pattern.
2. **Rule analyzer**: automatically detect many properties of the given block transition function, encoded by the table of 16 integers.
3. **Spaceship catcher**: catch, analyze and add to the library escaping spaceships. Useful for automatic search for the spaceships.
4. **GIF recorder**: record field in the GIF animation.
5. **Library**: store figures collection in the local library (Requires Web Storage support in browser).
6. **Load from URL**: load simulation parameters, including field state, from the URL arguments.


Source
------

Most of the code is written in CoffeeScript.

Requirements
------------
To build minified code, following NPM tools are required:

1. *coffee-script*: compile coffescript code
2. *browserify*: prepare application code for using in browser
2. *uglify-js*: minification of the JS
3. *mocha*: required for running tests

These tools are not included, and must be installed separately.
Additionally, *GNU Make* is required, because build system uses it.

Compiling
---------
Build system for this applicaiton uses GNU Make. To compile app using this system, first run:

    $ coffee configure.coffee

and then:

    $ make

After modifying files, you only need to run ```make```, configure is only needed after adding new files.

Alternatively, if you don't want to bother with this idiosyncratic build ssytem, you can compile everythign manually:

    $ coffee -o scripts scripts-src
    $ browserify scripts/application.js -o scripts/bundle.js
    $ uglifyjs --screw-ie8 scripts/bundle.js > scripts/minified.js﻿

To run application, open index.html. You can skip the last (minification) step, if replace "minified.js" with "bundle.js" in the index.html.

Credits
-------

Code for GIF generation is based on: https://github.com/antimatter15/jsgif


License
-------

Well, let's say MIT?


Single Rotation Rule SVG Demo
=============================

SVG file, animated with JavaScript program, demonstrating the "Single Rotation" reversible cellular automaton. 
Shows small field and transforms it slowly, step-by-step with each step animated.

File: revca-singlerot.svg
View it here: http://dmishin.github.io/js-revca/revca-singlerot.svg  (your browser must support SVG and JavaScript)

Following parameters can be controlled via URL arguments:
1. Animation speed: argument "speed". Default is 0.1
2. Animation contents: argument "quick". Possible values are 0 and 1, default is 0.
3. Initial pattern, in the RLE format: "rle".
4. Initial position of the pattern: arguments "x", "y"
5. Color palette for coloring cells. Must be ";"-separated list of the valid SVG colors. 


Example:

Simulation of the orthogonal c/14 spaceship:
```
.##..#.#
....##..
#....#..
```
Its RLE code is: `b2o2bobo$4b2o$o4bo`

See it in the demonstration:
[href="http://dmishin.github.io/js-revca/revca-singlerot.svg?rle=b2o2bobo$4b2o$o4bo&quick=1&x=2&y=6&palette=black;yellow](http://dmishin.github.io/js-revca/revca-singlerot.svg?rle=b2o2bobo$4b2o$o4bo&quick=1&x=2&y=6&palette=black;yellow)

Or in the [Simulator](http://dmishin.github.io/js-revca/index.html?rule=0,2,8,3,1,5,6,7,4,9,10,11,12,13,14,15&rle_x0=26&rle_y0=28&rle=b2o2bobo$4b2o$o4bo&step=8&frame_delay=100&size=64x64&cell_size=4,1).

