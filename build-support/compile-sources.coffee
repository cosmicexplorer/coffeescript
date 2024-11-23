{ BuildTask, ChecksumFiles } = require './caching'
{ spawnNodeProcess }         = require './subprocess'
{ createHash }               = require 'crypto'
path                         = require 'path'


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

  constructor: ({@coffeeSource, @jsOut}) ->
    super()
    unless @coffeeSource.match /\.(lit)?coffee$/
      throw new TypeError "coffee source file must end in .coffee or .litcoffee (was: '#{@coffeeSource}')"
    unless @jsOut.match /\.js$/
      throw new TypeError "js output file must end in .js (was: '#{@jsOut}')"

  inputSources: -> new ChecksumFiles [@coffeeSource]
  outputSources: -> new ChecksumFiles [@jsOut]

  execute: -> await spawnNodeProcess ['bin/coffee', '-c', '-o', @jsOut, @coffeeSource]
