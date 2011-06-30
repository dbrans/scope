# File header.
###
 * Scopejs v0.10.0
 * http://scopejs.org
 *
 * Copyright(c) 2011 Derek Brans <dbrans@gmail.com>
 * Released under the MIT License
###

# Scopejs is a library for defining and working with lexical scopes.
# Visit [scopejs.org](http://scopejs.org) for more information.

# ##Helpers

# isString and isFn are borrowed from underscorejs by way of CoffeeScript
isString = (x) -> !!(x is '' or (x and x.charCodeAt and x.substr)) 
isFn = (x) -> !!(x and x.constructor and x.call and x.apply) 

# Extend object `x` with the properties of all objects in `more`
extend = (x, more...) -> (x[k] = v for k,v of o) for o in more; x

# CoffeeScript runtime helpers
exports.COFFEESCRIPT_HELPERS = COFFEESCRIPT_HELPERS =
  __slice: Array::slice
  __bind: (fn, me) -> -> fn.apply me, arguments
  __indexOf: Array::indexOf or (item) ->
    return i if x is item for x, i in @
  __hasProp: Object::hasOwnProperty
  __extends: (child, parent) ->
    for key of parent
      child[key] = parent[key] if eval('__hasProp').call parent, key
      ctor = -> @constructor = child
      ctor:: = parent.prototype
      child.prototype = new ctor
      child.__super__ = parent::
      child

# ##class Scope
# This class represents a lexical scope.
exports.Scope = class Scope
  
  # The 'scoped eval' literal.
  EVAL_LITERAL = "(function(__expr){return eval(__expr)})"
  
  # ### Class methods
  
  # #### Scope.eval(expr)
  # A function to eval a given expression safely wrapped in a function
  # in the global scope.
  #    
  # `Scope.eval(expr)` has these properties:
  # 
  # 1. `Scope.eval("var x")` will not declare a new global. 
  # Whereas `evalInGlobalScope("var x")` will.
  # 2. `Scope.eval("x")` will not return the value of `x` in the 
  # current scope. Whereas `eval("x")` will.
  # 
  # `Scope.eval` provides the outer scope for all scoped evals.
  @_eval = `(1, eval)(EVAL_LITERAL)`
  
  # #### Scope::eval(context, expr)
  # Evaluate an expression in this scope.
  # 
  # The optional `context` parameter serves as the value of `this`
  # for the eval of `expr`.
  # 
  # `context.locals` may define additional locals visible only to `expr`.
  # 
  # ##### Argument Decompilation
  # The `expr` argument need not be a string: it can also be a function or 
  # an object that defines a `literalize` method. See `Scope.literalize`.
  # This means that you can recompile a function in another scope like this:
  #    
  #     var getXFromScope = scope.eval(function(){return x});
  #     log(getXFromScope()); // Prints the current value of x in the scope.
  #    
  @eval = (context, expr, literalize_ = literalize) -> 
    # Normalize arguments
    [context, expr] = [null, context] unless expr?
    # Code to declare and set locals
    locals = context?.locals and (for name of context.locals
      "var #{name} = this.locals.#{name};\n").join('') or ""
    # Code to declare and set literals
    literals = context?.literals and (for name, val of context.literals
      "var #{name} = #{literalize val};\n").join('') or ""
    # Set the value of `this` for this scope for this invocation.
    @set? '__context', context
    # eval expr in the context of locals and literals
    @_eval.call context, locals + literals + literalize_ expr
  
  # #### Scope::run(ctx, fn)
  # 'Run' a function in this scope. i.e., `literalize`, `eval` and `call`
  # the given function within this scope.
  #    
  #     log(scope.run(function(){return x})); // Prints the current value of x in the scope.
  # 
  @run = (ctx, fn) -> @eval ctx, fn, (fn) -> "#{literalize fn}.call(this)"
    
  # #### Scope.literalize(x)
  # Return a literal expression for `x`
  @literalize = literalize = (x) ->
    # A string must already be an expression.
    if isString x then x
    else if isFn x 
      # 'Decompile' a function using `Function::toString` (where supported)
      x = x.toString()
      # Remove name from named function
      x = x.replace /function[^\(]*\(/, "function ("
      "(#{x})"
    # Otherwise, `x` must literalize itself.
    else x.literal()

  # #### Class properties intended to be overridden.
  
  # List of reserved variable names.
  @reserved = ['__expr']
            
  # Create a getters / setters for the given name.
  @makeGetter = (name) ->       -> @get name
  @makeSetter = (name) -> (val) -> @set name, val, false
  
  @root = new @ {locals: COFFEESCRIPT_HELPERS}
  
  # #### Scope.create(options)
  # Returns a scope that extends the root scope
  # of this class. 
  # 
  # See `constructor` for description of options.
  @create = (options = {}) -> @root.extend options   
  
  # #### constructor(options)
  # Called with no arguments: creates a global scope.
  # 
  # There are two ways to define
  # local variables in the new scope: using _locals_
  # and _literals_.
  # 
  # ##### *param*: `options.locals` 
  # Describes local variable names and values to be declared and set 
  # in the target scope.
  # 
  #     var foo = {};
  #     
  #     var scope = Scope.create({
  #       locals: {foo: foo}
  #     });
  # 
  #     log(scope.eval('foo') === foo); // true
  # 
  # ##### *param*: `options.literals`
  # Describes local variable names to be declared and set to 
  # literal expressions eval'd in the target scope.
  # 
  #     scope = Scope.create({
  #       locals: {foo: 3},
  #       literals: {
  #         getFoo: "function(){return foo}"
  #       }
  #     });
  # 
  #     log(scope.eval('foo')); // 3
  constructor: (@options = {}) ->
    # The types of variables in options.
    varTypes = ['locals', 'literals']
    # Normalize options.
    @options[k] ?= {} for k in varTypes
    # #####The `__this` local variable
    # Within the target scope, `__this` refers to the Scope object for that 
    # target scope.
    @options.locals.__this = @
    {@parent} = @options
    # The last value of `this` when Scope::eval was called with a context.
    # Root scopes only.
    @options.locals.__context = null if not @parent
    # Register variable names declared in options.
    names = []
    names.push name for name of @options[k] for k in varTypes
    throw 'Reserved' for n in names when n in @constructor.reserved
    @names = names.concat @parent?.names or []
    # Compile the 'scoped eval'
    @_eval = (@parent or Scope).eval @options, EVAL_LITERAL
    # #####Exports
    # Exports allow direct access to locals inside the scope via
    # getters and setters (where support exists):
    # 
    #     var scope = Scope.create({locals: {foo: 0}});
    # 
    #     // Set a local variable inside the target scope (setters are by reference).
    #     scope.eval.foo = 5;
    #     log(scope.eval('foo'));      // 5
    # 
    #     // Get a local variable from the target scope.
    #     scope.eval('foo = 4');
    #     log(scope.eval.foo);         // 4
    # 
    # Exported variables are those that do not start with '_'
    exports = (x for x in @names when not x.match /^_/)
    throw 'Name collision' for x in exports when x of @
    C = @constructor
    if @__defineGetter__?
      for x in exports
        @__defineGetter__ x, C.makeGetter x
        @__defineSetter__ x, C.makeSetter x
    else 
      # In environments where `__defineGetter__` and `__defineSetter__` 
      # are not supported, `@[name]` is set once when the scope is created.
      @[x] = C.makeGetter(x).call @ for x in exports

  
  eval: @eval
  
  run: @run

  # #### Scope::set(name, val, isLiteral)
  # Set local variable to value.
  # `if isLiteral then literalize val`.
  # 
  # To set multiple values: `Scope.set(obj, isLiteral)`
  set: (name, val, isLiteral) ->
    if isString name then @_eval.call {val}, "#{name} = " + 
      (if isLiteral then literalize val else "this.val")
    else 
      [obj, isLiteral] = [name, val]
      @set name, val, isLiteral for name, val in obj
      
  # #### Scope::get(name)
  # Get a local value from this scope.
  get: (name) -> @_eval name

  # #### Scope::extend(options)
  # Create a new scope that extends this one, with the given options.
  # See `constructor` for a list of options.
  extend: (options = {}) -> 
    new (options.class or @constructor) extend options, parent: @
  