{ BuildTask, ChecksumFiles }               = require './caching'
{ collectNone, getCapture, invokeProcess } = require './subprocess'


exports.BuildDeps = class BuildDeps extends BuildTask
  identifier: -> 'build-deps'

  constructor: ({
    @trackedLockfile = 'package-lock.json',
    @installLockFile = 'node_modules/.package-lock.json',
  } = {}) -> super()

  inputSources: -> new ChecksumFiles [@trackedLockfile]
  outputSources: -> new ChecksumFiles [@installLockFile]
  print: -> "npm install: #{@trackedLockfile} -> #{@installLockFile}"

  execute: ->
    capture = getCapture 'stderr'
    proc = await invokeProcess 'npm', ['install', '.']
    capture proc
    await collectNone proc
