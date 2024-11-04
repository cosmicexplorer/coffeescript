# This file contains desired syntax and desired output.

###
jsdoc:
/**
 * @type {(x: number) => number}
 * /
var f;

f = function(x) {
  return x + 3;
}

.d.ts:
/**
 * @type {(x: number) => number}
 * /
declare var f: (x: number) => number;
###
# f!<[=> number]> = (x!<[number]>) -> x + 3
# equivalently (only top-level for now):
# f!<[(x: number) => number]> = (x) -> x + 3
f = (x) -> x + 3

###
jsdoc:
/**
 * @type {{a: number}}
 * /
var x;

x = {
  a: 3
};

.d.ts:
/**
 * @type {{a: number}}
 * /
declare var x: {
    a: number;
};
###
# x!<[{a: number}]> = {a: 3}
x = {a: 3}

# x = {a!<[number]>: 3}
# TODO: should the above be allowed? this isn't really a "place" or "deconstructing" expression:
#       it's just a literal key for a literal value. the reason we want this would be for e.g.:
# f = ({x!<[{a: number, b}]>: {a}}) -> a
#       where the above would get normalized to:
# f!<[({x: {a: number, b}}) => any]> = ({x: {a}}) -> a
#       i.e. it allows annotating type for the key "x", which is not a place expression since it is
#       being destructured. I think the correct way to handle this is to allow "x" to be a place
#       expression (bound in the function scope), *as well as* destructured. This is a general issue
#       with coffeescript destructuring expressions: that you can't perform the entire destructuring
#       in one go if you need to keep a reference to something you're also destructuring. e.g.:
# f = ({x}) ->
#   {a, b} = x
#   ... # do stuff with both a and x
#       It requires a separate statement (impossible on the repl) to have access to both "x" and "a"
#       in the same scope. Ideally, we have a "destructure but also keep this name" operator, like
#       rust's @ bindings (https://doc.rust-lang.org/book/ch18-03-pattern-syntax.html#-bindings):
# f = ({x@: {a, b}}) -> x + a
#       This resolves the prior conundrum for type annotations as well: now they can only apply to
#       place expressions, and the annotation for a place can be separate from the way it's
#       destructured:
# f = ({x!<[{a: number, b}]>@: {a}}) -> x + a
#       The above generates:
# /**
#  * @type {({x}: {a: number, b}) => any}
#  * /
# var f;
# f = function({x}) {
#   {a} = x
#   return x + a;
# }
#       The @ operator is pure syntax sugar for staged destructuring, and follows our semantics.
#
#       For the motivating example:
# x = {a!<[number]>@: 3}
#       This would fail to parse, because the right-hand side is not a place expression, so @ cannot
#       be used.
#
#       In array destructuring or function args, the @ works similarly, but with the inner
#       destructuring expression immediately after the @, instead of the "@:" used for objects:
# f = (a@{b}, [c@[d], ...e]) -> a + b + c + d + e
#       This is desugared to:
# f = (a, [c, ...e]) ->
#   {b} = a
#   [d] = c
#   a + b + c + d + e

###
jsdoc:
/**
 * @type {({a}: {a: string}) => string}
 * /
var g;

g = function({a: x}) {
  return x;
}

.d.ts:
/**
 * @type {({a}: {a: string}) => string}
 * /
declare var g: ({ a }: {
    a: string;
}) => string;
###
# g!<[=> string]> = ({a!<[string]>: x}) -> x
# equivalently (only top-level for now):
# g!<[(a: string) => string]> = ({a: x}) -> x
# this one does not rename the field:
# g!<[=> string]> = ({a!<[string]>) -> a
# equivalently (only top-level for now):
# g!<[(a: string) => string]> = ({a}) -> a
g = ({a: x}) -> x

###
jsdoc:
/**
 * @type {({a, b, c, e}: {a: number, b?: number, c: {d?: number}, e: [f: number]}) => number}
 * /
var h;

h = function({a, b = 3, c: {d = 3}, e: [f]}) {
  return a + b + d;
};

.d.ts:
/**
 * @type {({a, b, c, e}: {a: number, b?: number, c: {d?: number}, e: [f: number]}) => number}
 * /
declare var h: ({ a, b, c, e }: {
    a: number;
    b?: number;
    c: {
        d?: number;
    };
    e: [f: number];
}) => number;
###
# h!<[=> number]> = ({a!<[number]>, b!<[?number]> = 3, c: {d!<[?number]> = 3}, e: [f!<[number]>]}) ->
#   a + b + d + f
# equivalently, all at once (top-level only for now):
# h!<[({a, b, c, e}: {a: number, b?: number, c: {d?: number}, e: [f: number]}) => number]> = (
#   {a, b = 3, c: {d = 3}, e: [f]
# ) -> a + b + d + f
h = ({a, b = 3, c: {d = 3}, e: [f]}) ->
  a + b + d + f
