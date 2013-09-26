class WritableByteStream
  constructor:(chunkSize = 1024) ->
    @chunkSize = chunkSize
    @curChunkPos = 0
    @curChunk = @newChunk()
    @chunks = [@curChunk]

  ###
  How many bytes currently contained in the stream
  ###
  getSize: ->
    (@chunks.length - 1) * @chunkSize + @curChunkPos

  ###
  Create new chunk
  ###
  newChunk: ->
    try
      new Uint8Array(@chunkSize)
    catch e
      [] #not sure it worth it, but just for the case.

  ###
  Get data as base-64 string
  ###
  getB64Data: ->
    output = ""
    key = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    chr = []
    hasChrs = 0
    addChr = (c) ->
      if hasChrs >= 3
        encodeBlock()
        hasChrs = 0
      chr[hasChrs++] = c

    encodeBlock = ->
      enc1 = chr[0] >> 2
      enc2 = ((chr[0] & 3) << 4) | (chr[1] >> 4) 
      enc3 = if hasChrs<2 then 64 else ((chr[1] & 15) << 2) | (chr[2] >> 6)
      enc4 = if hasChrs<3 then 64 else chr[2] & 63
      output += (key.charAt(enc1) + key.charAt(enc2) + key.charAt(enc3) + key.charAt(enc4))

    lastChunkIdx = @chunks.length - 1
    for chunk, iChunk in @chunks
      chunkLen = if iChunk is lastChunkIdx then @curChunkPos else @chunkSize
      for j in [0 ... chunkLen] by 1
        addChr chunk[j]
    
    #last piece
    encodeBlock() if hasChrs > 0
    output

  writeByte: (val) ->
    p = @curChunkPos
    @curChunk[p++] = val
    if p < @chunkSize
      @curChunkPos = p
    else
      @curChunkPos = 0
      @chunks.push (@curChunk = @newChunk())

  writeUTFBytes: (string) ->
    for i in [0...string.length] by 1
      @writeByte string.charCodeAt(i)
    null
    
  writeBytes: (array, offset=0, length=array.length) ->
    for i in [ offset ... length ] by 1 #To simplify JS code
      @writeByte array[i]
    null

exports.WritableByteStream = WritableByteStream