{ BuildTask, ChecksumFiles }  = require './caching'
{ invokeProcess, captureErr } = require './subprocess'
{ createHash }                = require 'crypto'
path                          = require 'path'
process                       = require 'process'


exports.CompileSources = class CompileSources extends BuildTask
  @makeHasher: => createHash 'sha256'

  @digestNames: (names) =>
    hasher = @makeHasher()
    hasher.update name for name in names
    hasher.digest 'hex'

  extractNameKeys: ->
    digest = @constructor.digestNames [@coffeeSource, @jsOut]
    {name: srcName} = path.parse @coffeeSource
    {name: outName} = path.parse @jsOut
    {srcName, outName, digest}

  identifier: ->
    {srcName, outName, digest} = @extractNameKeys()
    "compile-sources-#{srcName}-#{outName}-#{digest}"

  constructor: ({@coffeeSource, @jsOut, @coffeeBin = 'bin/coffee'}) ->
    super()
    unless @coffeeSource.match /\.(lit)?coffee$/
      throw new TypeError "coffee source file must end in .coffee or .litcoffee (was: '#{@coffeeSource}')"
    unless @jsOut.match /\.js$/
      throw new TypeError "js output file must end in .js (was: '#{@jsOut}')"

  inputSources: -> new ChecksumFiles [@coffeeSource, @coffeeBin]
  outputSources: -> new ChecksumFiles [@jsOut]
  print: -> "coffee compile: #{@coffeeSource} -> #{@jsOut}"

  execute: (console) ->
    proc = await invokeProcess process.execPath, [@coffeeBin, '-c', '-o', @jsOut, @coffeeSource]
    await captureErr proc
