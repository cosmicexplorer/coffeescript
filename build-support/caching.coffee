assert         = require 'assert'
{ createHash } = require 'crypto'
fs             = require 'fs'
path           = require 'path'
{ performance }  = require 'perf_hooks'
stream         = require 'stream'
helpers        = require '../lib/coffeescript/helpers'


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


exports.ChecksumFiles = class ChecksumFiles
  constructor: (paths) ->
    @inputs = paths.map (p) -> path.resolve p
      .sort()
      .map (p) -> new FileContent p

  digestAll: -> await Promise.all @inputs.map (f) -> await Checksummed.digestContent f


class Attestation
  constructor: ({@inputSources, @outputSources, @path}) ->

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


exports.TaskFailed = class TaskFailed extends Error
  constructor: (task, cause) ->
    message = "task failed: #{task.print()}\n#{cause.message}"
    super message, {cause}
    @task = task

  title: -> @task.print()
  operation: -> @cause.operation?()
  reason: -> @cause.reason?()
  inner: -> @cause.inner?()


exports.BuildTask = class BuildTask
  identifier: -> throw new TypeError "unimplemented: #{@constructor.name}"
  inputSources: -> throw new TypeError "unimplemented: #{@constructor.name}"
  outputSources: -> throw new TypeError "unimplemented: #{@constructor.name}"
  print: -> throw new TypeError "unimplemented: #{@constructor.name}"

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

  cachedExecute: (console) ->
    if await @cacheIsValid()
      console.debug "task '#{@identifier()}' was fully cached!"
      console.debug "task '#{@identifier()}' is cached at '#{@attestationPath()}'"
      return
    console.info "task '#{@identifier()}' was not cached; executing"
    console.log @print()
    startTask = performance.now()

    await @execute(console).catch (e) => Promise.reject new TaskFailed @, e

    endTask = performance.now()
    console.info "task '#{@identifier()}' complete (#{endTask - startTask} ms)"
    console.debug "caching task '#{@identifier()}' at '#{@attestationPath()}'"
    await @writeCache()
