{ spawn }     = require 'child_process'
process       = require 'process'


exports.SubprocessError = class SubprocessError extends Error
  constructor: (@child, ...rest) -> super ...rest

  exe: -> @child.spawnfile
  args: -> @child.spawnargs

  # FIXME: why is shell quoting not provided in the stdlib? This is technically wrong!
  quoteArgs: -> @args().map((arg) -> "'#{arg}'").join ', '
  operation: -> "process [#{@quoteArgs()}]"

  reason: -> @message

exports.SpawnFailed = class SpawnFailed extends SubprocessError
  constructor: (child, cause) -> super child, "process spawn failed: #{cause.message}", {cause}

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
  constructor: (child, cause) -> super child, "process aborted: #{cause.message}", {cause}

exports.OutputCapturedError = class OutputCapturedError extends Error
  constructor: (capturedOutput, cause) ->
    message = if capturedOutput
      "#{cause.message}\n#{capturedOutput}"
    else cause.message
    super message, {cause}

    @capturedOutput = capturedOutput

  operation: -> @cause.operation?()
  reason: -> @cause.reason?()
  inner: -> @capturedOutput or null


# Async process spawning.
exports.invokeProcess = invokeProcess = (...spawnArgs) -> new Promise (resolve, reject) ->
  spawnFailed = (err) -> reject new SpawnFailed @, err
  spawn ...spawnArgs
    .on 'error', spawnFailed
    .on 'spawn', ->
      # The 'error' event is used for both spawn failure as well as aborts
      # (https://nodejs.org/api/child_process.html#event-error), so differentiate those here.
      @off 'error', spawnFailed
      resolve @

exports.collectProcess = collectProcess = (collect) -> (proc) -> new Promise (resolve, reject) -> (proc
  .on 'error', (err) -> reject new Aborted @, err
  .on 'exit', (code, signal) ->
    if signal?
      reject new SignalReceived @, signal
      return
    if code isnt 0
      reject new NonZeroExit @, code
      return
    resolve collect @)
exports.collectNone = collectNone = collectProcess -> null

captureOutputs =
  stdout: -> @stdout.pipe process.stdout
  stderr: -> @stderr.pipe process.stderr
  both: ->
    @stdout.pipe process.stdout
    @stderr.pipe process.stderr
  none: ->
exports.getCapture = getCapture = (arg) ->
  method = captureOutputs[arg] ? throw new TypeError "unrecognized capture arg: #{arg}"
  (proc) -> method.bind(proc)()


exports.spawnNodeProcess = (args, {output = 'stderr'} = {}) ->
  # Interpret the 'capture' arg before spawning the process.
  capture = getCapture output

  proc = await invokeProcess process.execPath, args
  capture proc

  await collectNone proc


exports.captureOutput = captureOutput = (proc) ->
  getOutChunks = do (proc) ->
    out = ''
    for await chunk from proc.stdout.setEncoding 'utf8'
      out += chunk
    for await chunk from proc.stderr.setEncoding 'utf8'
      out += chunk
    out
  collect = collectProcess -> getOutChunks
  collect(proc).catch (e) -> switch
    when e instanceof SubprocessError
      getOutChunks.then (outChunks) -> Promise.reject new OutputCapturedError outChunks, e
    else Promise.reject e
