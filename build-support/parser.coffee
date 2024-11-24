{ BuildTask, ChecksumFiles }     = require './caching'
{ invokeProcess, captureOutput } = require './subprocess'
util                             = require 'util'

exports.JisonParser = class JisonParser extends BuildTask
  identifier: -> 'jison-parser'

  constructor: ({
    @grammarPath = 'lib/coffeescript/grammar.js',
    @parserPath = 'lib/coffeescript/parser.js',
    @jisonScript = 'build-support/isolated-scripts/jison-script.coffee',
    @pkgLock = 'node_modules/.package-lock.json',
    @coffeeBin = 'bin/coffee',
  } = {}) -> super()

  inputSources: -> new ChecksumFiles [@grammarPath, @jisonScript, @pkgLock, @coffeeBin]
  outputSources: -> new ChecksumFiles [@parserPath]
  print: -> "jison generate: #{@grammarPath} -> #{@parserPath}"

  execute: (console, {useColors}) ->
    proc = await invokeProcess process.execPath, [@coffeeBin, @jisonScript, @grammarPath, @parserPath, @pkgLock]
    output = (await captureOutput proc).trim()

    header = 'jison output:'
    if useColors
      header = util.styleText ['underline', 'cyan', 'italic'], header
      output = util.styleText ['bgGray', 'cyanBright'], output
    console.debug header
    console.debug output
