{ createHash } = require 'crypto'
fs             = require 'fs'
stream         = require 'stream'


exports.Content = class Content
  describe: -> throw new TypeError "unimplemented: #{@constructor.name}"
  stream: -> throw new TypeError "unimplemented: #{@constructor.name}"

  class @Unavailable extends Error
    constructor: (source, why, cause = null) ->
      msg = "#{source.describe()} could not be read: #{why}"
      super msg, {cause}
      @source = source

exports.StringContent = class StringContent extends Content
  constructor: (@s) -> super()
  describe: -> "string(#{JSON.stringify @s})"
  stream: -> Promise.resolve stream.Readable.from @s

exports.FileContent = class FileContent extends Content
  constructor: (@p) -> super()
  describe: -> "path(#{@p})"
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


# p = new FileContent 'Cakefile'
# c = await Checksummed.digestContent p
# console.dir {p, c}

# p2 = new FileContent 'aaaaa'
# e = try
#   await Checksummed.digestContent p2
# catch e then e
# console.dir {p2, e}
# console.log e.stack



class Attestation
  @inputSeparator: ':'
  @outputSeparator: '|'

  @sanitizeHash: (hashValue, separator, descriptor) =>
    if hashValue.includes separator
      throw new TypeError "#{descriptor} hash value '#{hashValue}' cannot contain separator '#{separator}'"

  constructor: (@inputHashes, @outputHash) ->
    @inputHashes.forEach (i) => @constructor.sanitizeHash i, @constructor.inputSeparator, 'input'
    @constructor.sanitizeHash @outputHash, @constructor.outputSeparator, 'output'

  serialize: ->
    "#{@inputHashes.join @constructor.inputSeparator}#{@constructor.outputSeparator}#{@outputHash}"

  @deserialize: (value) ->
    [inputs, outputHash] = value.split @outputSeparator
    inputHashes = inputs.split @inputSeparator
    new @ inputHashes, outputHash


class CachedExecute
  constructor: (@inputPaths, @outputPath, @attestationPath) ->
    @inputPaths.sort()

  # checksumPaths: ->
  #   inputs: await Promise.all @inputPaths.map (p) ->
  #     path: p
  #     checksum: await checksumFile p
  #   output:
  #     path: @outputPath
  #     checksum:

  readAttestation: -> try
    await fs.promises.readFile @attestationPath, encoding: 'utf8'
  catch e then switch e.code
    when 'ENOENT'
      console.debug 'attestation file not found'
      null
    else throw e

  validateAttestation: ->
