fs      = require 'fs'
path    = require 'path'
process = require 'process'

[grammarInput, parserOutput, pkgLockInstalled] = process.argv[2..]

# NB: This will pull in Jison and other dependencies.
# NB: We call path.resolve() to ensure require() interprets it as a filesystem path and not
#     a module name.
{parser} = require path.resolve grammarInput
{symbols_, terminals_, productions_} = parser

errMsg = (msg) -> process.stderr.write "#{msg}\n"

do (pkgLockInstalled) ->
  installedPackagesManifest = JSON.parse fs.readFileSync pkgLockInstalled, encoding: 'utf8'
  {version, resolved, integrity} = installedPackagesManifest.packages["node_modules/jison"]
  errMsg "jison version: #{version}, resolved: #{resolved}, integrity: #{integrity}"

countKeys = (obj) -> (Object.keys obj).length

do ({symbols_, terminals_, productions_} = parser) ->
  numSyms = countKeys symbols_
  numTerms = countKeys terminals_
  numProds = countKeys productions_
  errMsg "parser stats: #{numSyms} symbols, #{numTerms} terminals, #{numProds} productions"


# Generate the parser js script and write it to the specified output path.
# We don't need `moduleMain`, since the parser is unlikely to be run standalone.
parserText = parser.generate(moduleMain: ->)
fs.writeFileSync parserOutput, parserText, encoding: 'utf8'
