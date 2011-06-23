# Tests for scopejs
# -----------------
# A variable we will reuse.
oldfoo = foo = 3

test 'Get a value from scope', ->
  scope = Scope.create locals: {foo}
  eq scope.eval('foo'), foo
  
test 'Set a value in scope', ->
  newfoo = 4
  scope = Scope.create locals: {foo}
  
  scope.eval "foo = #{newfoo}"
  eq scope.eval("foo"), newfoo

  # make sure we haven't stomped foo in this scope
  eq foo, oldfoo
  
  
test 'Set a complex value in scope', ->
  bar = {}
  newfoo = -> bar
  scope = Scope.create locals: {foo}
  
  scope.eval {newfoo}, "foo = this.newfoo"
  eq scope.eval("foo"), newfoo
  eq scope.eval("foo")(), bar
  
  # make sure we haven't stomped foo in this scope
  eq foo, oldfoo
 

test 'Get a value from scope - function version', ->
  scope = Scope.create locals: {foo}
  eq foo, scope.run -> foo

test 'Set a value in scope - function version', ->
  newfoo = 4
  scope = Scope.create locals: {foo}
  # CoffeeScript, careful with assignments!
  # foo is already declared here.
  scope.run {newfoo}, -> foo = @newfoo
  eq scope.eval('foo'), newfoo

  # make sure we haven't stomped foo in this scope
  eq foo, oldfoo
 
test 'Set a complex value in scope - function version', ->
  bar = {}
  newfoo = -> bar
  scope = Scope.create locals: {foo}
  
  scope.run {newfoo}, -> foo = @newfoo
  eq scope.eval("foo"), newfoo
  eq scope.eval("foo")(), bar
  
  # make sure we haven't stomped foo in this scope
  eq foo, oldfoo
 

test 'locals and closures', ->
  scope = Scope.create
    locals:{foo}
    literals: 
      f: -> foo
  eq scope.eval('f')(), foo

test 'this', ->
  scope = Scope.create
    locals:{foo}
    literals: 
      f: -> @foo
  eq scope.eval('f').call({foo}), foo

test 'named function', ->
  `function f() {return foo;}`
  scope = Scope.create
    locals:{foo}
    literals: {f}
  eq scope.eval('f')(), foo

# TODO more eval versions of all these tests.
test 'named function - eval version', ->
  `function f() {return foo;}`
  scope = Scope.create
    locals:{foo}
  eq foo, scope.run f


test 'function as string', ->
  scope = Scope.create
    locals:{foo}
    literals: 
      f: "function () { return foo;}"
  eq scope.eval('f')(), foo


test 'named function as string', ->
  scope = Scope.create
    locals:{foo}
    literals: 
      f: "function named() { return foo;}"
  eq scope.eval('f')(), foo

test 'compiled coffeescript as string', ->
  scope = Scope.create
    locals:{foo}
    literals: 
      f: (CoffeeScript.compile "-> foo", bare: true)
  eq scope.eval('f')(), foo


test 'coffeescript helpers', ->
  scope = Scope.create locals: {foo}
  eq foo, scope.run ->
    class FooClass
      constructor: (@foo) ->
      getFoo: => @foo
    (new FooClass foo).getFoo.call null
        
test 'exports', ->
  newfoo = 4
  scope = Scope.create 
    locals: {foo}
      
  # get
  eq foo, scope.foo
  
  # set
  scope.foo = newfoo
  eq newfoo, scope.eval 'foo'
  eq foo, oldfoo

okThrows = (f) ->
  try
    f()
    ok false
  catch e
    ok true
  
_GLOBAL = do -> @

test 'use of reserved name throws', ->
  okThrows ->
    Scope.create locals: __eval: null

test 'Set undeclared name throws', ->
  okThrows -> Scope.create().set {foo: 4}
  
test 'Temp locals', ->
  scope = Scope.create()
  eq foo, scope.eval locals: {foo}, "foo"
  okThrows -> scope.eval 'foo'
  