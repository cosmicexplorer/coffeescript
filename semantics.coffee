assert = require 'assert'
process = require 'process'
coffee = require './lib/coffeescript/index.js'

[input, ...] = process.argv[2..]


rawTokens = (input) -> {type, value} for [type, value] in coffee.tokens input

encodeTokens = (input) -> for {type, value} in rawTokens input
  if type.match /^[A-Z_]+$/
    if value.match /^\s+$/
      {whitespace: type, value: encodeURIComponent value}
    else
      {type, value}
  else
    assert (type is value.toString()), JSON.stringify {type, value}
    {punct: value}

tokenPrint = (input) -> for {punct, whitespace, type, value} in encodeTokens input
  if punct?
    ": #{punct}"
  else if whitespace?
    "#{whitespace}('#{value}')"
  else
    "#{type}(#{value})"

nodes = (input) -> coffee.nodes input
# .body.expressions[0].params[0].name.properties[0]

compiled = (input) -> coffee.compile input, bare: yes

evaled = (input) -> coffee.eval input


{TOK, AST, AST_PATH, COMP, EV} = process.env
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
else if EV?
  evaled input
else throw new Error('wtf')

console.log output
