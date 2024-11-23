{ BuildTask, ChecksumFiles }     = require './caching'
{ invokeProcess, captureOutput } = require './subprocess'
{ createHash }                   = require 'crypto'
path                             = require 'path'
process                          = require 'process'


class CompileSourcesBase extends BuildTask
  @makeHasher: => createHash 'sha256'

  @digestNames: (names) =>
    hasher = @makeHasher()
    hasher.update name for name in names
    hasher.digest 'hex'


exports.CompileBootstrapSources = class CompileBootstrapSources extends CompileSourcesBase
  extractNameKeys: ->
    digest = @constructor.digestNames [@coffeeSource, @jsOut]
    {name: srcName} = path.parse @coffeeSource
    {name: outName} = path.parse @jsOut
    {srcName, outName, digest}

  identifier: ->
    {srcName, outName, digest} = @extractNameKeys()
    "compile-bootstrap-sources-#{srcName}-#{outName}-#{digest}"

  constructor: ({@coffeeSource, @jsOut, @coffeeBin = 'bin/coffee'}) ->
    super()
    unless @coffeeSource.match /\.(lit)?coffee$/
      throw new TypeError "coffee source file must end in .coffee or .litcoffee (was: '#{@coffeeSource}')"
    unless @jsOut.match /\.js$/
      throw new TypeError "js output file must end in .js (was: '#{@jsOut}')"

  inputSources: -> new ChecksumFiles [@coffeeSource, @coffeeBin]
  outputSources: -> new ChecksumFiles [@jsOut]
  print: -> "bootstrap coffee compile: #{@coffeeSource} -> #{@jsOut}"

  execute: (console) ->
    proc = await invokeProcess process.execPath, [@coffeeBin, '-c', '-o', @jsOut, @coffeeSource]
    await captureOutput proc


exports.CompileRealSources = class CompileRealSources extends CompileSourcesBase
  constructor: ({
    @bootstrappedJsOut,
    @realJsOut,
  }) ->
    super()
    for jsOut in @bootstrappedJsOut
      unless jsOut.match /\.js$/
        throw new TypeError "bootstrap-compiled js input file must end in .js (was: '#{jsOut}')"
    unless @realJsOut.match /\.js$/
      throw new TypeError "final compiled js output file must end in .js (was: '#{@realJsOut}')"

  inputSources: -> new ChecksumFiles [@bootstrappedJsOut...]
  outputSources: -> new ChecksumFiles [@realJsOut]

  identifier: ->
    digest = @constructor.digestNames [@realJsOut]
    {name} = path.parse @realJsOut
    "compile-real-sources-#{name}-#{digest}"

  wrapInputs: -> @bootstrappedJsOut.map((p) -> "'#{p}'").join ', '
  print: -> "final coffee compile: [#{@wrapInputs()}] -> #{@realJsOut}"
