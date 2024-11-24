process = require 'process'

[commmandInput, ] = process.argv[2..]

require(commandInput).run()
