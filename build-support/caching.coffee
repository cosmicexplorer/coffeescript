assert          = require 'assert'
fs              = require 'fs'
helpers         = require '../lib/coffeescript/helpers'
path            = require 'path'
stream          = require 'stream'
util            = require 'util'
{ createHash }  = require 'crypto'
{ performance } = require 'perf_hooks'


exports.Content = class Content
  identifier: -> throw new TypeError "unimplemented: #{@constructor.name}"
  stream: -> throw new TypeError "unimplemented: #{@constructor.name}"

  class @Unavailable extends Error
    constructor: (source, why, cause = null) ->
      msg = "#{source.identifier()} could not be read: #{why}"
      super msg, {cause}
      @source = source

exports.StringContent = class StringContent extends Content
  constructor: (@s) -> super()
  identifier: -> "string(#{JSON.stringify @s})"
  stream: -> Promise.resolve stream.Readable.from @s

exports.FileContent = class FileContent extends Content
  constructor: (@p) -> super()
  identifier: -> "path(#{@p})"
  stream: -> new Promise (resolve, reject) =>
    fs.createReadStream @p
      .on 'error', (e) => reject switch e.code
        when 'ENOENT' then new @constructor.Unavailable @, 'file does not exist', e
        else e
      .on 'ready', -> resolve @


exports.Checksummed = class Checksummed
  @makeHasher: => createHash 'sha256'

  constructor: (@source, @checksum) ->

  @digestContent: (source) ->
    [digest] = (chunk for await chunk from (await source.stream())
      .pipe @makeHasher()
      .setEncoding 'hex')
    new @ source, digest


class OutputFiles
  sourcePaths: -> throw new TypeError "unimplemented: #{@constructor.name}"
  commitPaths: -> throw new TypeError "unimplemented: #{@constructor.name}"
  commit: (console) -> throw new TypeError "unimplemented: #{@constructor.name}"


exports.ChecksumFiles = class ChecksumFiles extends OutputFiles
  constructor: (paths) ->
    super()
    @sources = paths.map (p) -> path.resolve p
      .sort()
      .map (p) -> new FileContent p

  sourcePaths: -> @sources.map ({p}) -> p
  commitPaths: -> @sourcePaths()
  commit: (console) ->
    paths = @commitPaths()
    msg = paths.map((p) -> "'#{p}'").join ', '
    console.debug "commit no-op: [#{msg}]"
    Promise.resolve paths

  digestAll: -> await Promise.all @sources.map (f) -> await Checksummed.digestContent f


exports.BuildOutputMirroredFiles = class BuildOutputMirroredFiles extends ChecksumFiles
  constructor: (cacheDir, commitPaths) ->
    buildPaths = new Map ([p, path.join(cacheDir, p)] for p in commitPaths)
    super Array.from buildPaths.values()
    @buildPaths = buildPaths

  commitPaths: -> Array.from @buildPaths.keys()
  commit: (console) ->
    console.info "commit files: #{util.inspect @buildPaths}"
    Promise.all (for [target, source] from @buildPaths
      console.debug "commit copy #{source} -> #{target}"
      fs.promises.copyFile source, target
        .then -> target)

  digestAll: ->
    await Promise.all (for p in @sourcePaths()
      fs.promises.mkdir path.dirname(p), recursive: yes)
    await super()


exports.TaskFailed = class TaskFailed extends Error
  constructor: (task, cause) ->
    message = "task failed: #{task.print()}\n#{cause.message}"
    super message, {cause}
    @task = task

  title: -> @task.print()
  operation: -> @cause.operation?()
  reason: -> @cause.reason?()
  inner: -> @cause.inner?()

  print: (console, {useColors}) ->
    console.error "task failed: #{@title()}"

    operation = "operation: #{@operation()}"
    if useColors
      operation = util.styleText 'yellow', operation
    console.info operation

    reason = "reason: #{@reason()}"
    if useColors
      reason = util.styleText 'cyan', reason
    console.info reason

    if (inner = @inner())?
      console.error util.styleText 'reset', inner


class Attestation
  constructor: ({
    @inputSources,
    @outputSources,
    @path,
  }) ->

  class @NoCachedValue extends Error
    constructor: (source, why, cause = null) ->
      msg = "attestation could not be read: #{why}"
      super msg, {cause}
      @source = source

  class @OutputUnavailable extends Content.Unavailable
    constructor: (cause) -> super cause.source, 'output must be generated', cause

  class @InputNotFound extends Content.Unavailable
    constructor: (cause) -> super cause.source, 'internal task dependency error', cause

  read: -> try JSON.parse await fs.promises.readFile @path, encoding: 'utf8'
  catch e then throw switch e.code
    when 'ENOENT' then new @constructor.NoCachedValue @, 'file does not exist', e
    else e

  make: ->
    [inputs, outputs] = await Promise.all [
      @inputSources.digestAll()
      @outputSources.digestAll().catch (e) => Promise.reject switch
        when e instanceof Content.Unavailable
          new @constructor.OutputUnavailable e
        else e
    ]
    ret =
      inputs: {}
      outputs: {}
    for {source, checksum} in inputs
      ret.inputs[source.identifier()] = checksum
    for {source, checksum} in outputs
      ret.outputs[source.identifier()] = checksum
    ret

  write: ->
    generated = await @make()
    encoded = JSON.stringify generated, null, 2
    await fs.promises.writeFile @path, encoded, encoding: 'utf8'

  @objectEquals: (a, b) =>
    if helpers.isString a
      assert helpers.isString b
      return a.toString() == b.toString()
    assert helpers.isPlainObject a
    assert helpers.isPlainObject b
    keysA = new Set Object.keys a
    keysB = new Set Object.keys b
    if keysA.symmetricDifference(keysB).size > 0
      return no
    for key from keysA
      unless @objectEquals a[key], b[key]
        return no
    yes

  # TODO: named returns and breaks for nested control flow!
  cacheIsValid: ->
    try cached = await @read()
    catch e
      return no if e instanceof @constructor.NoCachedValue
      throw e
    try generated = await @make()
    catch e
      return no if e instanceof @constructor.OutputUnavailable
      throw e
    @constructor.objectEquals cached, generated


exports.BuildTask = class BuildTask
  identifier: -> throw new TypeError "unimplemented: #{@constructor.name}"
  inputSources: -> throw new TypeError "unimplemented: #{@constructor.name}"
  outputSources: -> throw new TypeError "unimplemented: #{@constructor.name}"
  print: -> throw new TypeError "unimplemented: #{@constructor.name}"

  @buildOutputBaseDir: '.build-output'
  buildOutputDir: -> path.join @constructor.buildOutputBaseDir, @identifier()

  @attestationDir: '.attestations'
  @makeAttestationFilename: (id) => "#{id}.attestation.json"
  @makeAttestationPath: (id) =>
    filename = @makeAttestationFilename id
    path.join @attestationDir, filename
  attestationPath: -> @constructor.makeAttestationPath @identifier()
  asAttestation: -> new Attestation
      inputSources: @inputSources()
      outputSources: @outputSources()
      path: @attestationPath()

  cacheIsValid: -> await @asAttestation().cacheIsValid()
  writeCache: -> await @asAttestation().write()
  deleteCache: -> try await fs.promises.unlink @attestationPath()
  catch e then switch e.code
    when 'ENOENT'
    else throw e

  execute: -> throw new TypeError "unimplemented: #{@constructor.name}"

  doCommit: (console) -> await @outputSources().commit console

  cachedExecute: (console, {commit, useColors}) ->
    if await @cacheIsValid()
      console.debug "task '#{@identifier()}' was fully cached!"
      console.debug "task '#{@identifier()}' is cached at '#{@attestationPath()}'"
      if commit
        await @doCommit console
      return
    console.info "task '#{@identifier()}' was not cached; executing"
    console.log @print()
    startTask = performance.now()

    await @execute(console, {useColors}).catch (e) => Promise.reject new TaskFailed @, e

    endTask = performance.now()
    console.info "task '#{@identifier()}' complete (#{endTask - startTask} ms)"
    console.debug "caching task '#{@identifier()}' at '#{@attestationPath()}'"
    await @writeCache()
    if commit
      await @doCommit console
