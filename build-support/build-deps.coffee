{ BuildTask, ChecksumFiles }                  = require './caching'
{ collectProcess, getCapture, invokeProcess } = require './subprocess'


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
    collect = collectProcess -> null
    proc = await invokeProcess 'npm', ['install', '.']
    capture proc
    await collect proc
