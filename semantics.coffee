assert = require 'assert'
process = require 'process'
coffee = require './lib/coffeescript/index.js'

[input, ...] = process.argv[2..]


rawTokens = (input) -> {type, value} for [type, value] in coffee.tokens input

encodeTokens = (input) -> for {type, value} in rawTokens input
  value = value.toString()
  if type in ['INDENT', 'OUTDENT']
    {dent: type, value}
  else if type.match(/^[A-Z_]+$/) or type is 'BIN?'
    if value.match /^\s+$/
      {whitespace: type, value}
    else
      {type, value}
  else
    assert (type is value), JSON.stringify {type, value}
    {punct: value}

tokenPrint = (input) -> for {punct, whitespace, dent, type, value} in encodeTokens input
  if punct?
    ": #{punct}"
  else if dent?
    if dent is 'INDENT'
      "=> (#{value})"
    else
      assert dent is 'OUTDENT', dent
      "<= (#{value})"
  else if whitespace?
    "#{whitespace}(#{JSON.stringify value})"
  else
    "#{type}(#{value})"

nodes = (input) -> coffee.nodes input
# .body.expressions[0].params[0].name.properties[0]

compiled = (input) -> coffee.compile input, bare: yes

astCompile = (input) -> coffee.compile input, ast: yes

evaled = (input) -> coffee.eval input

recurseEntries = (o, cb) ->
  queue = [o]
  while (cur = queue.splice(0)).length > 0
    for x in cur
      unless cb x
        return
      switch
        when coffee.helpers.isPlainObject x
          queue.push (Object.values x)...
        when Array.isArray x
          queue.push x...

fmtOut = (o, {depth, rmFields, stringify}) ->
  if coffee.helpers.isString o
    return process.stdout.write o

  recurseEntries o, (x) ->
    return yes unless x?
    for f in rmFields
      delete x[f]
    yes
  if stringify
    process.stdout.write JSON.stringify o, null, 2
  else
    console.dir o, {depth}


{TOK, AST, AST_PATH, COMP, ASTCOMP, EV, DEPTH, RM_FIELDS, STRINGIFY} = process.env
output = if TOK?
  switch TOK
    when 'raw' then rawTokens input
    when 'enc' then encodeTokens input
    else (tokenPrint input).join '\n'
else if AST?
  ret = nodes input
  if AST_PATH?
    eval "ret#{AST_PATH}"
  else
    ret
else if COMP?
  compiled input
else if ASTCOMP?
  astCompile input
else if EV?
  evaled input
else throw new Error('environment command not found')

depth = if DEPTH? then parseInt DEPTH else null
rmFields = if RM_FIELDS?
  (s for s in RM_FIELDS.split ',' when s)
else ['locationData', 'loc', 'range', 'start', 'end', 'tokens']
stringify = STRINGIFY?
fmtOut output, {depth, rmFields, stringify}
