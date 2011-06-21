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

# ##class Scope.
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
    # Give x a chance to decompile itself.
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
  
  # ##Instance creation
  
  # ### Scope.create(options)
  # Returns a scope that extends the root scope
  # of this class. There are two ways to define
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
  @create = (options) -> @root.extend options

  # The constructor takes the same options as Scope.create.
  constructor: (@options = {}) ->
    # The types of variable options.
    varTypes = ['values', 'literals']
    # Normalize and read options
    @options[k] ?= {} for k in varTypes
    @options.values.__scope = @
    {@parent} = @options
    # Register variable names
    names = []
    names.push name for name of @options[k] for k in varTypes
    throw 'Reserved' for n in names when n in @reserved
    @names = names.concat @parent?.names or []
    # Create a 'scoped eval' by evaling `this.literal` in the 
    # parent scope.
    @_eval = @parent?.eval({locals: @options.values}, @) or globalEval 
    # Export Locals
    exports = (x for x in @names when not x.match /^_/)
    throw 'Name collision' for x in exports when x of @
    if @__defineGetter__?
      for x in exports
        @__defineGetter__ x, @exportGetter x
        @__defineSetter__ x, @exportSetter x
    else 
      @[x] = @getter(x)() for x in exports

  
  # Returns a literal expression for this scope's `_eval` method.
  literal: -> 
    (for name, val of @options.literals
      "var #{name} = #{literalize val};\n").join('') + 
    EVAL_LITERAL
  
  # Create a getter / setter for the given name.
  exportGetter: (name) -> => @get name
  exportSetter: (name) -> (val) => @set name, val
  
  # ##Runtime (post-initialize) methods
  
  # Evaluate an expression in this scope.
  # 
  # The `expr` parameter gets literalized before being eval'd
  # 
  # The optional `ctx` parameter serves as the value of 'this'
  # for the expression.
  # 
  # `ctx.locals` may define additional local values only
  # visible to expr.
  eval: (ctx, expr) -> 
    [ctx, expr] = [{}, ctx] unless expr
    locals = 
      if ctx.locals then (for name of ctx.locals
        "var #{name} = this.locals.#{name};\n").join ''
      else ""
        
    @_eval.call ctx, locals + literalize expr
  
  # 'Run' a function in this scope. i.e., literalize, eval and call
  # the given function within this scope.
  run: (ctx, fn) -> 
    [ctx, fn] = [{}, ctx] unless fn
    @eval ctx, "#{literalize fn}.call(this)"

  # Set a local, or multiple locals in this scope.
  set: (name, val, isLiteral = false) ->
    if isString name 
      throw 'Undeclared' unless name in @names
      @_eval.call {val}, "#{name} = " + 
        if isLiteral then literalize val else "this.val"
    else 
      # Set multiple values.
      obj = name; isLiteral = val
      @set name, val, isLiteral for name, val of obj
    @
  
  # Get a value from this scope
  get: (name) -> @_eval name
  
  # Incorporate given locals and closures into a
  # scope that extends this one.
  extend: (options = {}) -> new @constructor extend options, parent: @
     
  #Initialize the class
  @initialize()
  