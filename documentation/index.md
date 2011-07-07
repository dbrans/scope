# ScopeJS
A JavaScript library for defining and working with lexical scopes.

[ScopeJS is hosted on github](http://github.com/dbrans/scope).

Latest version: [0.10.1](http://github.com/dbrans/scope)

## Table of Contents
- [Installation and Usage](#usage)
- [Theory](#theory)
- [API](#api)
- [Annotated Source](documentation/docs/scope.html)
- [CoffeeScript Support](#coffee)

## Overview

    // Create a new lexical scope
    var scope = Scope.create({
      locals: {foo: 3},
      literals: {
        multiplyFoo: function(val) {foo *= val;}
      }
    });
    
    // Call a local function.
    scope.multiplyFoo(4);
    
    // Evaluate an expression locally.
    scope.eval('foo++');
    
    // Get a local variable.
    log(scope.foo); // 13
    
    // Extend a scope.
    var inner = scope.extend({
      locals: {bar: 'bar'}
    });
    
    // Inner scope has access to the outer scope:
    inner.foo = 6;    
    log(scope.foo));        // 6
    
    // But outer scope does not have access to the inner scope:
    log(scope.eval('bar')); // Error: bar is not defined.

~anchor:usage
## Installation

There are two ways to install ScopeJS: via npm or via git.

### NPM

1. If you haven't already, [install npm](http://howtonode.org/introduction-to-npm). 
2. `npm install -g scope`
(Leave off the -g if you don't wish to install globally.)


### Git
To install from source, you should have [CoffeeScript](http://coffeescript.org) installed.

Then run:

    git clone git://github.com/dbrans/scope.git
    cd scope
    cake install

## Including ScopeJS in your project.

### CommonJS Environment (e.g., Nodejs)

    var Scope = require('scope').Scope;
    var scope = Scope.create(...);

### Browser Environment
Include `browser/scope.js` in your html page:

    <script type="text/javascript" src="PATH_TO_SCOPE/browser/scope.js"></script>

`browser/scope.js` defines `Scope` as a global variable. So you can just go
ahead and use it:
    
    var scope = Scope.create(...);

## Community
Please use the [github page for ScopeJS](http://github.com/dbrans/scope)
to discuss and raise issues about ScopeJS.

~anchor:theory
## Theory
### A 'scoped eval' function

Consider this function literal as a string:
    
    var EVAL_LITERAL = "(function (expr) {return eval(expr)})";

Eval-ing this string in some lexical scope creates a 'scoped eval': 
a function that, if passed outside of the current scope, can evaluate 
expressions inside that scope. Here's a demonstration:

    var scopeEval = (function() {
      var x = 3;
      return eval(EVAL_LITERAL);
    })();
    
    log(scopeEval('x')); // 3
    log(eval('x'));      // Error: x is not defined

In general, given a list of variable names `var1`, `var2`, ..., you can dynamically 
create a lexical scope where those variables are defined like this:

    var vars = ['var1', 'var2', ..., 'varN'];
    
    var scopeEval = (function() {
      eval("var " + vars.join(',') + ';' + EVAL_LITERAL);
    });
    
This idea of a scoped eval function is at the heart of ScopeJS. 

Let's develop this idea a little bit.

### _Current_ vs _Target_ scopes
Let's call the scope in which our examples are imagined to run 
the _current scope_ 
and the scope in which a scopeEval expression runs, the _target scope_.

For simplicity, in our examples the current scope is the outer scope of
the target scope. In other words, 

    // For simplicity:
    // CURRENT SCOPE
    var scopeEval = (function() {
      // TARGET SCOPE
      eval("var " + vars.join(',') + ';' + EVAL_LITERAL);
    });
    
In ScopeJS, however, the target scope lives somewhere else and cannot see the 
current scope (see the `Scope.eval` class method in the 
[Annotated Source](documentation/docs/scope.html))

### Undeclared Variables
In these examples, the variables var1, var2, etc. refer to variables that
are already declared in the target scope. Any assignment to undeclared 
variables is a typo and would create global variables.

### Literal Expressions
We can evaluate array, object and function literals inside the target scope. 
Those literals have access to local variables. Consider:

    scopeEval('var1 = 3');
    
    var obj = scopeEval('[var1]');

    log(obj[0]);           // 3


#### Function Literals and Closures
Function literals that are eval'd in a scope close over local variables in that
scope and can manipulate them directly:

    var addToVar = scopeEval('(function(x){var1 += x})');
    
    addToVar(2);
    
    log(scopeEval('var1')); // 5

### Extending the Target Scope
As you may have noticed, it's impossible to
declare a new variable in the target scope, once it is created.
This is because the eval happens in the function local scope described 
by EVAL_LITERAL.
This means that newly declared variables only exist for the duration of that 
function's invocation:

    // Here 'newvar' exists:
    log(scopeEval('var newvar = 3; newvar')); // 3
    
    // ...but here it doesn't:
    scopeEval('newvar'); // Error: newvar is not defined

Instead, we create an inner scope where new variables are defined. 

    var newvars = ['newvar1', 'newvar2', ...];
    var innerEval = scopeEval('var ' + newvars.join(',') + ';' + EVAL_LITERAL);

Because we used `scopeEval` to create our lexical scope, innerEval and scopeEval 
share variables var1, var2, etc. In addition, innerEval has it's own variables
newvar1, newvar2, ...

    // var1 is visible in both scopes
    innerEval('var1 = 6');
    log(scopeEval('var1'));      // 6
    
    // newvar1 is only visible in the inner scope
    innerEval('newvar1 = 'A');
    log(scopeEval('newvar1'));   // Error: newvar1 is not defined.

We might say that `innerEval` _extends_ `scopeEval` because `innerEval` includes 
`scopeEval`'s variables and declares new ones. 

`scopeEval` is actually the _outer_ lexical scope of `innerEval`, or rather the target 
scopes of those two functions. A static view of the nested
scopes we've created so far might look like this:
  
    // GLOBAL SCOPE
    (function() {
      // scopeEval's target scope
      var var1, var2, ...;
      (function () {
        // innerEval's target scope
        var newvar1, newvar2, ...;
      })()
    })()

    
~anchor:api
## API
For API documentation, please refer to the [annotated source](documentation/docs/scope.html)

~anchor:coffee
## CoffeeScript support
Every root scope defines all the coffeescript helpers that are currently generated by the CoffeeScript
compiler. This means that recompiling functions that were once compiled from CoffeeScript will 
work fine:

    # This is coffeescript
    scope.eval ->
       # invoke CoffeeScript's __bind runtime helper.
       =>

If you have a string of CoffeeScript code that you want to compile or run inside a target scope,
use 

    CoffeeScript.compile code, bare:true 

to compile `code` first. 'Native' CoffeeScript eval/compile
support could be envisioned for the future.
       
One important caveat when __setting a variable in the target scope__ inside a CoffeeScript function: 
The CoffeeScript compiler does lexical analysis around a function to decide if a variable has been seen
before or if it needs to be declared inside the function. 
So, unless you have a local variable with the same name in the current scope, the CoffeeScript compiler will 
declare a variable with that name inside your function, even if that variable exists in the target scope.
This function-local variable will mask the one in the target scope:

    scope = Scope.create
      locals:
        foo: 3
      literals:
        # Won't have the desired effect.
        setFoo: (val) -> foo = val

In the above code, calling `scope.setFoo 4` will have no effect since, in the current scope,
 CoffeeScript compiles `(val) -> foo = val` to 

    function(val) {
      var foo;
      return foo = val;
    }

A fix which analyzes decompiled CoffeeScript functions is possible.



