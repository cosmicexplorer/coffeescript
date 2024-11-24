{ BuildTask, ChecksumFiles, BuildOutputMirroredFiles } = require './caching'
{ invokeProcess, captureOutput }                       = require './subprocess'
{ createHash }                                         = require 'crypto'
path                                                   = require 'path'
process                                                = require 'process'


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
  outputSources: -> new BuildOutputMirroredFiles @buildOutputDir(), [@jsOut]
  print: -> "bootstrap coffee compile: #{@coffeeSource} -> [#{@jsOut}]"

  jsOutputPath: ->
    [jsOut] = @outputSources().sourcePaths()
    jsOut

  execute: (console) ->
    proc = await invokeProcess process.execPath, [@coffeeBin, '-c', '-o', @jsOutputPath(), @coffeeSource]
    await captureOutput proc


exports.CompileRealSources = class CompileRealSources extends CompileSourcesBase
  @fromDependencies: ({jisonParserTask, bootstrapCompileTasks}) ->
    parserInputPath = jisonParserTask.parserOutputPath()
    jsInputPaths = (t.jsOutputPath() for t in bootstrapCompileTasks)
    commandJsInput = jsInputPaths.find (p) -> path.basename(p) is 'command.js'
    unless commandJsInput?
      throw new TypeError "could not find command.js among build js inputs: #{jsInputPaths}"

  constructor: ({
    @bootstrappedJsOut,
    @coffeeSource,
    @realJsOut,
    @bootstrappedJsCommandOut,
    @realCompileScript = 'build-support/isolated-scripts/compile-real.coffee',
    @coffeeBin = 'bin/coffee',
  }) ->
    super()
    for jsOut in @bootstrappedJsOut
      unless jsOut.match /\.js$/
        throw new TypeError "bootstrap-compiled js input file must end in .js (was: '#{jsOut}')"
    unless @coffeeSource.match /\.(lit)?coffee$/
      throw new TypeError "coffee source file must end in .coffee or .litcoffee (was: '#{@coffeeSource}')"
    unless @realJsOut.match /\.js$/
      throw new TypeError "final compiled js output file must end in .js (was: '#{@realJsOut}')"
    unless @bootstrappedJsCommandOut.match /\.command\.js$/
      throw new TypeError "bootstrap-compiled command.js must end in command.js (was: #{@bootstrappedJsCommandOut})"

  inputSources: -> new ChecksumFiles [@realCompileScript, @coffeeBin, @coffeeSource, @bootstrappedJsOut...]
  outputSources: -> new BuildOutputMirroredFiles @buildOutputDir(), [@realJsOut]

  identifier: ->
    digest = @constructor.digestNames [@realJsOut]
    {name} = path.parse @realJsOut
    "compile-real-sources-#{name}-#{digest}"

  print: -> "final coffee compile: [#{@coffeeSource}] -> #{@realJsOut}"

  realJsOutputPath: ->
    [realJsOut]= @outputSources().sourcePaths()
    realJsOut

  execute: (console) ->
    proc = await invokeProcess process.execPath, [@coffeeBin, @realCompileScript, @bootstrappedJsCommandOut, '-c', '-o', @realJsOutputPath(), @coffeeSource]
    await captureOutput proc
