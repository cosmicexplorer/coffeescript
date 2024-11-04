/**
 * @type {(x: number) => number}
 */
var f;

/**
 * @type {{a: number}}
 */
var x;

/**
 * @type {({a}: {a: string}) => string}
 */
var g;

/**
 * @type {({a, b, c, e}: {a: number, b?: number, c: {d?: number}, e: [f: number]}) => number}
 */
var h;

f = function(x) {
  return x + 3;
};

x = {
  a: 3
};

g = function({
  a: x
}) {
  return x;
};

console.log(g({a: "asdf"}));

h = function({a, b = 3, c: {d = 3}, e: [f]}) {
  return a + b + d + f;
};

console.log(h({a: 3, c: {}, e: [5]}));
