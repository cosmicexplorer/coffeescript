# Use this with tsc-map-check.coffee, like `coffee tsc-map-check.coffee typecheck-example.coffee`.

###*
 * @type {(x: number) => number}
###
f = (x) -> x

f("asdf")

# NB: applying a block comment to any other top-level declaration just concatenates them in the
#     output, so this trick only works for exactly one decl. it's also unable to annotate the actual
#     assignment `f = function(x) { ... }`, just the initial `var f;` declared at top. both of those
#     require modifying coffeescipt codegen, which is the next step.
