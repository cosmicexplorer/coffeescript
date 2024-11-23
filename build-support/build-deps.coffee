{ BuildTask, ChecksumFiles }  = require './caching'
{ captureOutput, invokeProcess } = require './subprocess'


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

  execute: ->
    proc = await invokeProcess 'npm', ['install', '.']
    await captureOutput proc
