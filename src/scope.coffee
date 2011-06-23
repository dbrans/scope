# File header.
###
 * Scopejs v0.8.0
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
  # `Scope.eval` provides the outer scope for all scopes in Scopejs.
  @eval = `(1, eval)(EVAL_LITERAL)`

  # #### Scope.literalize(x)
  # Return a literal expression for `x`
  @literalize = literalize = (x) ->
    # A string is a literal expression of some other value.
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
  
  # These locals are defined in the root scope.
  @rootLocals =
    # CoffeeScript runtime helpers
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
  
  # List of reserved variable names.
  @reserved = ['__expr']
            
  # Create a getters / setters for the given name.
  @makeGetter = (name) -> 
    -> @_eval name
  @makeSetter = (name) -> 
    (val) -> @_eval.call {val}, "#{name} = this.val"
  
  # #### Class initializer
  # Call this function at the end of your Scope subclass to
  # create global and root scopes for your class.
  @initialize = -> 
    
    # Create a global scope for this class
    @global = new @()
    
    # Create a root scope for this class. 
    # All scopes may extend this scope.
    # It contains the rootLocals.
    @root = @global.extend locals: @rootLocals
  
  # #### Scope.create(options)
  # Returns a scope that extends the root scope
  # of this class. 
  # 
  # See constructor for description of options.
  @create = (options) -> @root.extend options

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
    # #####The `__scope` local variable
    # Within the target scope, `__scope` refers to the Scope object for that 
    # target scope.
    @options.locals.__scope = @
    {@parent} = @options
    # Register variable names declared in options.
    names = []
    names.push name for name of @options[k] for k in varTypes
    throw 'Reserved' for n in names when n in @constructor.reserved
    @names = names.concat @parent?.names or []
    # Create this scope's 'scoped eval'
    @_eval = 
      unless @parent? then Scope.eval
      else
        # Concatenate and assign all local literals
        literals = (for name, val of @options.literals
          "var #{name} = #{literalize val};\n").join('')
        # Eval `expr` in the parent scope with local values.
        @parent.eval @options, literals + EVAL_LITERAL
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
      @[x] = C.makeGetter(x)() for x in exports

  
  # #### Scope::eval(ctx, expr)
  # Evaluate an expression in this scope.
  # 
  # The optional `ctx` parameter serves as the value of `this`
  # for the eval of `expr`.
  # 
  # `ctx.locals` may define additional locals visible only to `expr`.
  # 
  # ##### Argument Decompilation
  # The `expr` argument need not be a string: it can also be a function or 
  # an object that defines a `literal` method. See `Scope.literalize`.
  # This means that you can recompile a function in another scope like this:
  #    
  #    var getXFromScope = scope.eval(function(){return x});
  #    log(getXFromScope()); // Prints the current value of x in the scope.
  #    
  eval: (ctx, expr) -> 
    [ctx, expr] = [{}, ctx] unless expr
    locals = 
      if ctx.locals then (for name of ctx.locals
        "var #{name} = this.locals.#{name};\n").join ''
      else ""
        
    @_eval.call ctx, locals + literalize expr
  
  # #### Scope::run(ctx, fn)
  # 'Run' a function in this scope. i.e., `literalize`, `eval` and `call`
  # the given function within this scope.
  #    
  #    log(scope.run(function(){return x})); // Prints the current value of x in the scope.
  # 
  run: (ctx, fn) -> 
    [ctx, fn] = [{}, ctx] unless fn
    @eval ctx, "#{literalize fn}.call(this)"

  # #### Scope::extend(options)
  # Create a new scope that extends this one, with the given options.
  # See `constructor` for a list 
  extend: (options = {}) -> new @constructor extend options, parent: @
     
  #Initialize this class
  @initialize()
  