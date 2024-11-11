assert = require 'assert'
process = require 'process'

coffee = require './lib/coffeescript/index.js'

###
# Token types for debugging
# see tag:/makeToken:/token:/makeLocationData: methods in lexer.coffee!

# each token is an array:
[tag, value, loc] = token

# ...but also has some optional data:
{
  generated?: bool = no,
  indentSize?: number,
  origin?: <token>,
  # NB: also added to `value` with Object.assign: see addTokenData
  data?: {} = {}, # arbitrary data
}
###
class InternTable
  @defaultProperty: Symbol 'global-table'

  constructor: (@generatedProperty = @constructor.defaultProperty, @table = new Map) ->
    assert.equal 'symbol', typeof @generatedProperty
    assert.ok @table instanceof Map

  @idCounter = 0
  gensym: (value) -> Symbol "key(#{@constructor.idCounter++})|#{@keyFormat value}"

  keyFormat: (value) -> value.toString()

  internNew: (value) ->
    sym = @gensym value

    backref = {sym, table: @}
    wrapped = Object.defineProperty value, @generatedProperty,
      configurable: no
      enumerable: no
      writable: no
      value: backref

    @table.set sym, wrapped
    wrapped

  getInternKey: (obj) ->
    throw new TypeError "object #{obj} not wrapped!" unless Object.hasOwn obj, @generatedProperty
    obj[@generatedProperty]

  dereference: (sym) ->
    throw new TypeError "symbol #{sym} not interned in table #{@}" unless @table.has sym
    @table.get sym


class TokenTable extends InternTable
  constructor: (table) ->
    prop = Symbol 'token-table'
    super prop, table

  keyFormat: ([type, value, ...]) ->
    if type is value then value
    else "#{type}=#{value}"

tokenTable = new TokenTable

rawTokens = (input) -> tokenTable.internNew token for token in coffee.tokens input

ID_MAPPING_FIELDS = ['origin']
RECOGNIZED_TOKEN_FIELDS = [
  'data'
  'generated'
  'indentSize'
  'spaced'
  'newLine'
  ...ID_MAPPING_FIELDS
]
extractTokenMetadata = do (tokenTable) -> (token) ->
  ret = null
  for fieldName in RECOGNIZED_TOKEN_FIELDS
    continue unless Object.hasOwn token, fieldName
    ret ?= {}
    metadataFieldValue = token[fieldName]
    value = switch  # TODO: could be `switch fieldName ...`!
      when fieldName in ID_MAPPING_FIELDS
        {sym: originSym, table} = tokenTable.getInternKey metadataFieldValue
        assert Object.is table, tokenTable
        originSym
      else
        metadataFieldValue
    ret[fieldName] = value
  ret


locField = Symbol 'location-data-field'
normalizeTokens = do (locField, tokenTable) -> (input) -> for curToken in rawTokens input
  [tag, value, loc] = curToken

  {sym, table} = tokenTable.getInternKey curToken
  assert Object.is table, tokenTable

  ret = {tag}

  if (metadata = extractTokenMetadata curToken)?
    ret.meta = metadata

  ret.value = switch typeof value
    when 'number'
      # This is an indent token.
      assert.ok tag in ['INDENT', 'OUTDENT'], {tag}
      {indentValue: value}
    when 'object'
      switch tag
        when 'INDENT', 'OUTDENT'
          assert.ok metadata?.generated, {tag}
          {indentValue: value.innerVal()}
        else value
    when 'string'
      # This corresponds to exactly the string from the input.
      value
    else throw new TypeError "unrecognized token value type: '#{typeof value}' for '#{value}'"

  ret = Object.defineProperty ret, locField,
    configurable: no
    enumerable: no
    writable: yes
    value: loc

  ret

indentTypes =
  INDENT: 'in'
  OUTDENT: 'out'

metaField = Symbol 'meta-data-field'
encodeTokens = do (metaField, indentTypes) -> (input) -> for curToken in normalizeTokens input
  {tag, value, meta} = curToken

  encoded = switch  # TODO: could be `switch tag ...`!
    when Object.hasOwn indentTypes, tag
      indentType = indentTypes[tag]

      {indentValue} = value
      assert.equal 'number', typeof indentValue, {value}

      ret =
        dent: indentType
        width: indentValue

      {indentSize} = meta ? {}
      if indentSize?
        ret.start = indentSize

      ret
    when tag.match /^[A-Z_]+\??$/
      switch
        when tag is 'TERMINATOR'
          assert.equal value.toString(), '\n', {value}
          {terminator: value}
        when value.toString().match /^\s+$/
          {whitespace: tag, value: encodeURIComponent value}
        else
          {tag, value}
    else
      assert.equal tag, value, JSON.stringify {tag, value}
      {punct: value}

  if meta?
    encoded = Object.defineProperty encoded, metaField,
      configurable: no
      enumerable: no
      writable: yes
      value: meta

  {generated} = meta ? {}
  if generated?
    encoded.generated = generated

  encoded

tokenPrint = (input) -> for encodedToken in encodeTokens input
  {punct, whitespace, tag, value, dent, start, width, terminator} = encodedToken
  if terminator?
    assert.equal terminator, '\n'
    'TERMINATOR'
  else if punct?
    ": #{punct}"
  else if whitespace?
    "#{whitespace}('#{value}')"
  else if dent?
    prefix = if start? then "@#{start}" else ''
    "dent(#{dent}, #{width})#{prefix}"
  else if tag is 'PARAM_START'
    assert.equal value, '('
    '@params: (...'
  else if tag is 'PARAM_END'
    assert.equal value, ')'
    '@params: ...)'
  else
    "#{tag}(#{value})"

nodes = (input) -> coffee.nodes input

DEFAULT_PATH = '.body.expressions'
indexByExpr = (pathExpr) ->
  pathExpr ?= DEFAULT_PATH
  (value) -> eval "value#{pathExpr}"

compiled = (input) -> coffee.compile input, bare: yes

evaled = (input) -> coffee.eval input


{TOK, AST, AST_PATH, COMP, EV} = process.env

output = (input) -> if TOK?
  switch TOK
    when 'raw' then rawTokens input
    when 'norm' then normalizeTokens input
    when 'enc' then encodeTokens input
    else (tokenPrint input).join '\n'
else if AST?
  (indexByExpr (AST_PATH ? null)) nodes input
else if COMP?
  compiled input
else if EV?
  evaled input
else throw new Error('wtf')

[input, ...] = process.argv[2..]

console.log output(input)
