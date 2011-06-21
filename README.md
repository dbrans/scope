# ScopeJS
An object-oriented library for defining and working with lexical scopes.

## Overview
    // Create a new lexical scope
    var scope = Scope.create({
        values: {
          foo: 3
        },
        literals: {
          setFoo: function(val) {
            foo = val;
          }
        }
      });
    
    // Call local functions
    scope.setFoo(4);
    
    // Set and get local variables.
    scope.eval('foo++');
    log(scope.get('foo')); // 5
    
    // Extend a scope.
    var inner = scope.extend({
        values: {
          bar: 'bar'
        }
      });
      
    // Set variables in the outer scope.
    inner.eval('foo++');    
    log(scope.foo)); // 6
    log(scope.eval('bar')); // Error: bar is not defined.

## Installation
### NPM
### Git
## Useage
### Server-side
### In the browser    
    
## Theory
### A 'scoped eval' function
Given variable names ['var1', 'var2', ..., 'varN'] 
you can build a string 'scopeExpr1' that prints like this:

    "(function() {
       var var1, var2, ..., varN;
       return function (expr) {
         return eval(expr);
       };
     })()"

As you might observe, evaluating `scopeExpr1` returns a 'scoped eval' 
function: a function that evaluates its argument in a lexical scope 
where `var1`, `var2`, etc., are declared.

    var scopeEval = evalInGlobalScope(scopeExpr1);

_(`evalInGlobalScope` is some function that eval's an expression
so that current scope is not visible to that expression)._

    // set var1 to 3 inside the scope.
    scopeEval('var1 = 3');  
    log(scopeEval('var1')); // prints 3
    
    // The current scope is unaffected
    log(var1)                // Error: var1 is not defined.

This idea of a scoped eval function is at the heart of ScopeJS. 

Let's develop this idea a little bit.

### Current scope vs target scope
Let's call the scope in which our examples are 
imagined to run the _current scope_ 
and the scope in which a scopeEval expression runs, the _target scope_.

### Declared variables
Like in any scope, the list of declared variable names in a target scope
is important. If we evaluate `undeclared = 3` in the target
scope then we would create and set the global variable 'undeclared' to 3.

In these examples, the variables var1, var2, etc. refer to variables that
are already declared in the target scope. Any assignment to undeclared 
variables is a typo.

### Literal Expressions
We can eval array, object and function literals inside the scope. Those literals
have access to local variables. Consider:

    var obj = scopeEval('[var1]');

    log(obj[0]);           // 3


### Function Literals and Closures
Function literals that are eval'd in a scope close over local variables in that
scope and can manipulate them directly:

    var addToVar = scopeEval('(function(x){var1 += x})');
    
    addToVar(2);
    
    log(scopeEval('var1')); // 5

### Setting Locals to Literal Values
Consider these expressions:
    
    scopeEval('var1 = 3');
    scopeEval('var2 = [var1]');
    scopeEval('var3 = function(x){var1 += x}');
    
In each case, a local variable is set to the value of evaluating a literal expression. In
general, we can set any declared variable to a literal value 
like this:

    function setLocalToLiteral(name, expr) {
      scopeEval(name + " = " + expr);
    }

### Setting Locals to an arbitrary value
Sometimes you want to set a local variable to a value you already have on hand. 

    var foo = 3;
    function getFoo (x) {foo = x};
    
Suppose we wanted to use `getFoo` inside the target scope. We can pass it into 
the scope using 'this':

    scopeEval.call({value: getFoo}, "var2 = this.value");

Now `var2` in the target scope refers to `getFoo` in the current scope:

    log(getFoo === scopeEval('var2'))    // true
    
    // You can call it from within the target scope.
    scopeEval('var2(4)');
    
    // foo is changed in the current scope
    log(foo);             // 4
    
In general, you can set any declared local variable by
reference like this:

    function setLocalToValue(name, value) {
      scopeEval.call({value: value}, name + " = this.value");      
    }

### Extending a Target Scope
As you may have noticed, it's hard to see a way to
declare a new variable name in a target scope, once it is created.

    scopeEval('var newvar = 3');
    scopeEval('newvar'); // error, 
    
This is because eval is called from within a function in the target 
scope (refer to `scopeExpr1` at the top to see this). 
Hence, declared variables only exist for the duration of that 
function's invocation.

    log(scopeEval('var newvar = 3; newvar')); // 3

To extend a target scope, we'll need to eval a new scoped
eval _inside_ the target scope.

We'll start by creating a new `scopeExpr2` from variable names
['varA', 'varB', ..., 'varZ'] that prints like this:

    "var varA, varB, ..., varZ;
     function (expr) {
       return eval(expr);
     }"

Instead of using `globalEval` this time, we'll eval our expression with scopeEval:

    scopeEval2 = scopeEval(scopeExpr2);

_Notice that we don't need the outer function wrapper that we used in 
`scopeExpr1`. The wrapper was used to avoid declaring global variables.
We don't need the wrapper for the same reason that we cannot declare new variables
in a pre-existing scope: The eval already happens inside a function._

Now scopeEval2 and scopeEval share variables var1, var2, etc.
In addition, scopeEval2 declares it's own vars varA, varB, etc.

    scopeEval2('var1 = 6');
    log(scopeEval('var1'));   // 6
    scopeEval2('varA = 'A');
    log(scopeEval('varA'));   // Error: varA is not defined.

We could describe the relationship between scope1 (scopeEval's target scope)
and scope2 (scopeEval2's target scope) as "scope2 extends scope1" or "scope1
is the outer scope of scope2". Lexically speaking, scope1 actually _is_ the outer 
scope of scope2. We can see this by analyzing the nested lexical scopes in `scopeExpr1`:
  
    // GLOBAL SCOPE
    (function() {
      // SCOPE1
      var var1, var2, ..., varN;
      return function (expr) {
        // SCOPE2 lives in here!
        return eval(expr);
      };
    })()

A scope whose immediate outer scope is the global scope is a 'root scope'. Scope1 is an 
example of a root scope.
    
## ScopeJS
I think we have covered enough concepts to make it easy to talk about what 
ScopeJS does.

In a nutshell, ScopeJS provides object-oriented way to define, 
manipulate and extend target scopes.

### Scope.create(options)
scope.js exports a single value: class `Scope`. The class method `Scope.create(options)` 
creates a target scope with the given options. Let's look at the
most important of those options: `locals` and `compile`

#### `options.locals` 
Describes variable names and values to be declared and set 
_by reference_ in the target scope.

    var foo = 3;
    
    var scope = Scope.create({
      locals: {foo: foo}
    });

    log(scope.eval('foo')); // 3

#### `options.compile` 
Describes variable names and expressions to be declared and set 
to scope-compiled values in the target scope.

    scope = Scope.create({
      locals: {foo: 3},
      compile: {
        getFoo: "function(){return foo}"
      }
    });

    log(scope.eval('foo')); // 3

### Scope::eval(ctx, expr)
Eval expr in the this scope. Returns the result.

Scope::eval takes an optional `ctx` argument which, for convenience, is the value of `this`
for `expr`.

    log(scope.eval({foo: 3}, "this.foo")) // 3

#### `ctx.locals`
`ctx.locals` describes a set of local variables that will be visible
only to the expression being evaluated.

    log(scope({locals: {foo: 3}}, "foo")) // 3

    scope("foo");        // Error: foo is not defined


### Scope::compile(ctx, expr)
Scope-compile an expression and return the result. See below for how Scope::compile differs from 
Scope::eval.

#### Argument Decompilation
The `expr` argument to a scope's 'compile' and 'eval' methods need not be a string. 
Whenever a Scope object is asked to compile/eval an argument, it first 'decompiles' the
argument. The decompilation algorithm looks something like this:

1. If `arg` is a string, then it is already decompiled
2. A function is decompiled using `arg.toString()` (where support exists).
3. Any other value is given the opportunity to decompile itself using `arg.decompile()` (For example,
Scope::decompile() yields the scope expression of scope).

#### Function Decompilation
In particular, in environments where Function::toString returns the source code of a 
function, you can use functions instead of strings to scope-compile functions.

    function foo() {
      return var1;
    }

    scopeFoo = scope.compile(foo);
    
    log(scopeFoo());          // 3

#### Scope::compile(expr) vs Scope::eval(expr)
These two methods behave identically, except when it comes to a function argument. 
Scope::compile(someFunction) will scope-compile someFunction and return the result. 
Scope::eval(someFunction) will scope-compile and call someFunction (with the current value of 'this'),
returning the result of that call. Thus giving the feel of evaluating someFunction's body as an 
expression.

### Getters and Setters
A scope instance provides a couple of mechanisms for getting and setting
variables inside the target scope:

#### Scope::get(name)
Get the current value of a local variable.

#### Scope::set(name, value, useCompile)
Set the current value of a local variable. If `useCompile` is `true`, then `value` gets scope-compiled.

#### Scope Exports: Getters and setters on 'Scope::eval'
Getters and setters attached to `scope.eval` allow direct access to values inside the scope via
getters and setters (where support exists):

    // Set a local variable inside the target scope (setters are by reference).
    scope.eval.foo = 5;
    log(scope.eval('foo'));      // 5
    
    // Get a local variable from the target scope.
    scope.eval('foo = 4');
    log(scope.eval.foo);         // 4

In environments where __defineGetter__/__defineSetter__ are not supported, `scope.eval[name]`
is set once when the scope is created to the be the initial value of the local variable.
    
### The `__scope` variable
Within the target scope, `__scope` refers to the Scope object for that 
target scope. Like all others, this variable is exported: `scope.eval.__scope` refers back to
`scope`.

## CoffeeScript support
Every root scope defines all the coffeescript helpers that are currently generated by the CoffeeScript
compiler. This means that recompiling functions that were once compiled from CoffeeScript will 
work fine:

    # This is coffeescript
    scope.eval ->
       # invoke CoffeeScript's __bind runtime helper.
       =>

If you have a string of CoffeeScript code that you want to compile or run inside a target scope,
use `CoffeeScript.compile code, bare:true` to compile `code` first. 'Native' CoffeeScript eval/compile
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
      compile:
        # Won't have the desired effect.
        setFoo: (val) -> foo = val

In the above code, calling `scope.setFoo 4` will have no effect since, in the current scope,
 CoffeeScript compiles `(val) -> foo = val` to 

    function(val) {
      var foo;
      return foo = val;
    }

A fix which analyzes decompiled CoffeeScript functions is possible.

