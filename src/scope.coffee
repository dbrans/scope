###
 * Scopejs v0.8.0
 * http://scopejs.org
 *
 * Copyright(c) 2011 Derek Brans <dbrans@gmail.com>
 * Released under the MIT License
###

# Scopejs is an object-oriented library for defining and working with lexical scopes.

# ###Helpers

# isString and isFn are borrowed from underscorejs by way of CoffeeScript
isString = (x) -> !!(x is '' or (x and x.charCodeAt and x.substr)) 
isFn = (x) -> !!(x and x.constructor and x.call and x.apply) 

# Extend object `x` with the properties of all objects in `more`
extend = (x, more...) -> (x[k] = v for k,v of o) for o in more; x

# ##class Scope
# This class represents a lexical scope.
exports.Scope = class Scope
  
  # Literal 'scoped eval' function
  EVAL_LITERAL = "(function(__expr){return eval(__expr)})"

  # Eval the given expression in the global scope, safely wrapped in
  # a function.
  @globalEval = globalEval = `(1, eval)(EVAL_LITERAL)`

  # Decompile a value for later recompilation in another scope.
  @literalize = literalize = (x) -> 
    if isString x then x
    else if isFn x 
      # Decompile a function using Function::toString (where supported)
      x = x.toString()
      # Remove name from named function
      x = x.replace /function[^\(]*\(/, "function ("
      "(#{x})"
    # Otherwise, let `x` decompile itself.
    else x.literal()

  # These values are defined in every root scope.
  @rootValues =
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
  
  # Reserved variable names
  reserved: @reserved = ['__expr']
            
  # ##Class initialization
  # Call this function at the end of your Scope subclass definition.
  @initialize = -> 
    
    # Create a global scope for this class
    @global = new @()
    
    # Create a root scope for this class. 
    # All scopes may extend this scope.
    # It contains the rootValues.
    @root = @global.extend values: @rootValues
  
  # Create a getters / setters for the given name.
  @makeGetter = (name) -> 
    -> @_eval name
  @makeSetter = (name) -> 
    (val) -> @_eval.call {val}, "#{name} = this.val"
  
  # ### Scope.create(options)
  # Returns a scope that extends the root scope
  # of this class. 
  # 
  # See constructor for description of options.
  @create = (options) -> @root.extend options

  # ### constructor(options)
  # There are two ways to define
  # local variables in the new scope: using _values_
  # and _literals_.
  # 
  # #### *param*: `options.values` 
  # Describes local variable names and values to be declared and set 
  # in the target scope.
  # 
  #     var foo = {};
  #     
  #     var scope = Scope.create({
  #       values: {foo: foo}
  #     });
  # 
  #     log(scope.eval('foo') === foo); // true
  # 
  # #### *param*: `options.literals`
  # Describes local variable names to be declared and set to 
  # literal expressions eval'd in the target scope.
  # 
  #     scope = Scope.create({
  #       values: {foo: 3},
  #       literals: {
  #         getFoo: "function(){return foo}"
  #       }
  #     });
  # 
  #     log(scope.eval('foo')); // 3
  constructor: (@options = {}) ->
    # The types of variable options.
    varTypes = ['values', 'literals']
    # Normalize and read options.
    @options[k] ?= {} for k in varTypes
    @options.values.__scope = @
    {@parent} = @options
    # Register variable names in options.
    names = []
    names.push name for name of @options[k] for k in varTypes
    throw 'Reserved' for n in names when n in @reserved
    @names = names.concat @parent?.names or []
    # Create a 'scoped eval'
    @_eval = 
      unless @parent? then globalEval
      else
        # Concatenate and set all literals, ending with EVAL_LITERAL
        expr = (for name, val of @options.literals
          "var #{name} = #{literalize val};\n").join('') + 
          EVAL_LITERAL
        # Eval `expr` in the parent scope with local values.
        @parent.eval {locals: @options.values}, expr
    # Exports: created getters and setters for exported variables
    exports = (x for x in @names when not x.match /^_/)
    throw 'Name collision' for x in exports when x of @
    C = @constructor
    if @__defineGetter__?
      for x in exports
        @__defineGetter__ x, C.makeGetter x
        @__defineSetter__ x, C.makeSetter x
    else 
      @[x] = C.makeGetter(x)() for x in exports

  
  # ### Scope::eval(ctx, expr)
  # Evaluate an expression in this scope.
  # 
  # The `expr` parameter gets literalized before being eval'd
  # 
  # The optional `ctx` parameter serves as the value of `this`
  # for the eval of `expr`.
  # 
  # `ctx.locals` may define additional local values visible only to `expr`.
  eval: (ctx, expr) -> 
    [ctx, expr] = [{}, ctx] unless expr
    locals = 
      if ctx.locals then (for name of ctx.locals
        "var #{name} = this.locals.#{name};\n").join ''
      else ""
        
    @_eval.call ctx, locals + literalize expr
  
  # ### Scope::run(ctx, fn)
  # 'Run' a function in this scope. i.e., `literalize`, `eval` and `call`
  # the given function within this scope.
  run: (ctx, fn) -> 
    [ctx, fn] = [{}, ctx] unless fn
    @eval ctx, "#{literalize fn}.call(this)"

  # ### Scope::extend(options)
  # Create a new scope that extends this one, with the given options.
  # See `constructor` for a list 
  extend: (options) -> new @constructor extend options, parent: @
     
  #Initialize this class
  @initialize()
  