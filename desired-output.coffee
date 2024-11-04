# This file contains desired syntax and desired output.

###
jsdoc:
/**
 * @type {(x: number) => number}
 * /
var f;

/**
 * @param {number} x
 * @returns {number}
 * /
f = function(x) {
  return x + 3;
}

.d.ts:
/**
 * @type {(x: number) => number}
 * /
declare var f: (x: number) => number;
###
# f<[=> number]> = (x<[number]>) -> x + 3
# f<[(x: number) => number]> = (x) -> x + 3
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
# x = {a<[number]>: 3}
# x<[{a: number}]> = {a: 3}
x = {a: 3}

###
jsdoc:
/**
 * @type {({a}: {a: string}) => string}
 * /
var g;

/**
 * @param {{a: string}} _
 * @returns {string}
 * /
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
# g<[=> string]> = ({a<[string]>: x}) -> x
# this one does not rename the field:
# g<[=> string]> = ({a<[string]>}) -> a
g = ({a: x}) -> x

###
jsdoc:
/**
 * @type {({a, b, c, e}: {a: number, b?: number, c: {d?: number}, e: [f: number]}) => number}
 * /
var h;

/**
 * @param {{a: number, b?: number, c: {d?: number}, e: [f: number]}} _
 * @returns number
 * /
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
# h<[=> number]> = ({a<[number]>, b<[?number]> = 3, c: {d<[?number]> = 3}, e: [f<[number]>]}) ->
#   a + b + d
h = ({a, b = 3, c: {d = 3}, e: [f]}) ->
  a + b + d + f
