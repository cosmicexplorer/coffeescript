{ BuildTask, ChecksumFiles }  = require './caching'
{ invokeProcess, captureOutput } = require './subprocess'

exports.JisonParser = class JisonParser extends BuildTask
  identifier: -> 'jison-parser'

  constructor: ({
    @grammarPath = 'lib/coffeescript/grammar.js',
    @parserPath = 'lib/coffeescript/parser.js',
    @jisonScript = 'build-support/jison-script.coffee',
    @pkgLock = 'node_modules/.package-lock.json',
    @coffeeBin = 'bin/coffee',
  } = {}) -> super()

  inputSources: -> new ChecksumFiles [@grammarPath, @jisonScript, @pkgLock, @coffeeBin]
  outputSources: -> new ChecksumFiles [@parserPath]
  print: -> "jison generate: #{@grammarPath} -> #{@parserPath}"

  execute: ->
    proc = await invokeProcess process.execPath, [@coffeeBin, @jisonScript, @grammarPath, @parserPath]
    await captureOutput proc
