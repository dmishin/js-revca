###
Exact palette quantizer. Returns palette as array of bytes
###
exports.exactPalette = (rgbaImage, indexImage) ->
  pal = []
  rgb2index = {}
  j = 0
  for i in [0 ... rgbaImage.length] by 4
    r = rgbaImage[i]
    g = rgbaImage[i + 1]
    b = rgbaImage[i + 2]
    rgb = r | (g << 8) | (b << 16)
    idx = rgb2index[rgb]
    if idx is `undefined`
      if pal.length < 256 * 3        
        #OK, just add new color to the rgb2index
        idx = (pal.length / 3) | 0
        rgb2index[rgb] = idx
        pal.push r
        pal.push g
        pal.push b
      else #rgb2index is too big
        idx = 0
    indexImage[j] = idx
    ++j
  pal
