{ BuildTask, ChecksumFiles } = require './caching'
{ spawnNodeProcess }         = require './subprocess'

exports.JisonParser = class JisonParser extends BuildTask
  identifier: -> 'jison-parser'

  constructor: ({
    @grammarPath = 'lib/coffeescript/grammar.js',
    @parserPath = 'lib/coffeescript/parser.js',
    @jisonScript = 'build-support/jison-script.coffee',
  } = {}) -> super()

  inputSources: -> new ChecksumFiles [@grammarPath, @jisonScript]
  outputSources: -> new ChecksumFiles [@parserPath]

  execute: -> await spawnNodeProcess ['bin/coffee', @jisonScript, @grammarPath, @parserPath]
