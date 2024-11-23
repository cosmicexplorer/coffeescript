process = require 'process'
util    = require 'util'

class Styler
  constructor: ({colors} = {}) ->
    @colors = colors ? yes

  @styleTable: util.inspect.colors

  @lookupStyle: (style) => @styleTable[style] ? throw new TypeError "style not found: '#{style}'"

  @passThrough: (str) -> str

  @doStylize = (...styles) =>
    starts = []
    ends = []
    for style in styles
      [start, end] = @lookupStyle style
      starts.push start
      ends.unshift end
    (str) -> "\x1B[#{starts.join ';'}m#{str}\x1B[#{ends.join ';'}m"

  stylize: (...styles) ->
    if @colors then @constructor.doStylize(...styles) else @constructor.passThrough

  @doReset: '\x1B[0m'

  reset: -> if @colors then @constructor.doReset else ''


exports.setupStyler = ({colors} = {}) ->
  return if global.styler?

  if process.env.NODE_DISABLE_COLORS
    colors = no
  unless process.stdout.hasColors()
    colors = no

  styler = new Styler {colors}

  global.styler = styler
  global.stylize = (...args) -> styler.stylize ...args
