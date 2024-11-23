fs      = require 'fs'
path    = require 'path'
process = require 'process'

[grammarInput, parserOutput] = process.argv[2..]

# NB: This will pull in Jison and other dependencies.
# NB: We call path.resolve() to ensure require() interprets it as a filesystem path and not
#     a module name.
{parser} = require path.resolve grammarInput
{symbols_, terminals_, productions_} = parser

# Generate the parser js script and write it to the specified output path.
# We don't need `moduleMain`, since the parser is unlikely to be run standalone.
parserText = parser.generate(moduleMain: ->)
fs.writeFileSync parserOutput, parserText, encoding: 'utf8'
