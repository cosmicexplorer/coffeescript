{ BuildTask, ChecksumFiles }     = require './caching'
{ captureOutput, invokeProcess } = require './subprocess'
util                             = require 'util'


exports.BuildDeps = class BuildDeps extends BuildTask
  identifier: -> 'build-deps'

  constructor: ({
    @trackedSpecFile = 'package.json',
    @trackedLockfile = 'package-lock.json',
    @installLockFile = 'node_modules/.package-lock.json',
  } = {}) -> super()

  inputSources: -> new ChecksumFiles [@trackedSpecFile, @trackedLockfile]
  outputSources: -> new ChecksumFiles [@installLockFile]
  print: -> "npm install: [#{@trackedSpecFile}, #{@trackedLockfile}] -> #{@installLockFile}"

  execute: (console, {useColors}) ->
    proc = await invokeProcess 'npm', ['install', '.']
    output = (await captureOutput proc).trim()

    header = 'npm output:'
    if useColors
      header = util.styleText ['underline', 'yellow', 'italic'], header
      output = util.styleText ['bgGray', 'yellowBright'], output
    console.debug header
    console.debug output
