{ spawn } = require 'child_process'
process   = require 'process'


exports.SubprocessError = class SubprocessError extends Error
  constructor: (@child, ...rest) -> super ...rest
  exe: -> @child.spawnfile
  args: -> @child.spawnargs

exports.SpawnFailed = class SpawnFailed extends SubprocessError
  constructor: (child, cause) -> super child, 'process spawn failed', {cause}

exports.ProcessCompletedError = class ProcessCompletedError extends SubprocessError
exports.SignalReceived = class SignalReceived extends ProcessCompletedError
  constructor: (child, signal) ->
    super child, "signal received: '#{signal}'"
    @signal = signal
exports.NonZeroExit = class NonZeroExit extends ProcessCompletedError
  constructor: (child, code) ->
    super child, "non-zero exit code: #{code}"
    @code = code
exports.Aborted = class Aborted extends ProcessCompletedError
  constructor: (child, cause) -> super child, 'process aborted', {cause}


# Async process spawning.
invokeProcess = (...spawnArgs) -> new Promise (resolve, reject) ->
  spawnFailed = (err) -> reject new SpawnFailed @, err
  spawn ...spawnArgs
    .on 'error', spawnFailed
    .on 'spawn', ->
      # The 'error' event is used for both spawn failure as well as aborts
      # (https://nodejs.org/api/child_process.html#event-error), so differentiate those here.
      @off 'error', spawnFailed
      resolve @

collectProcess = (collect) -> (proc) -> new Promise (resolve, reject) -> (proc
  .on 'error', (err) -> reject new Aborted @, err
  .on 'exit', (code, signal) ->
    if signal?
      reject new SignalReceived @, signal
      return
    if code isnt 0
      reject new NonZeroExit @, code
      return
    resolve collect @)
collectNone = collectProcess -> null

captureOutputs =
  stdout: -> @stdout.pipe process.stdout
  stderr: -> @stderr.pipe process.stderr
  both: ->
    @stdout.pipe process.stdout
    @stderr.pipe process.stderr
  none: ->
getCapture = (arg) ->
  method = captureOutputs[arg] ? throw new TypeError "unrecognized capture arg: #{arg}"
  (proc) -> method.bind(proc)()


exports.spawnNodeProcess = (args, {output = 'stderr'} = {}) ->
  # Interpret the 'capture' arg before spawning the process.
  capture = getCapture output

  proc = await invokeProcess process.execPath, args
  capture proc

  await collectNone proc
