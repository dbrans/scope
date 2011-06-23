fs = require 'fs'
path = require 'path'
CoffeeScript  = require 'coffee-script'
{exec: exec_} = require 'child_process'


# ANSI Terminal Colors borrowed from CoffeeScript's Cakefile
bold  = '\033[0;1m'
red   = '\033[0;31m'
green = '\033[0;32m'
reset = '\033[0m'


# Log a message with a color borrowed from CoffeeScript's Cakefile
log = (message, color = '', explanation) ->
  console.log color + message + reset + ' ' + (explanation or '')

srcfiles = ['scope']

exec = (cmd, cb) -> 
  exec_ cmd, (error, stdout, stderr) ->
    log error, red if error
    log stderr, red if stderr
    cb?() unless error

task 'doc', 'Build ScopeJS Documentation', ->
  exec 'cd documentation; docco ../src/*.coffee', ->

    {Showdown} = require './documentation/vendor/showdown'
    md = fs.readFileSync './documentation/index.md', 'utf8'
    html = Showdown.makeHtml md
    html = html.replace /~anchor:(\w+)/g, '<div id="$1"></div>'
    index = """
      <!DOCTYPE html> 
      <html> 
      <head> 
        <meta http-equiv="content-type" content="text/html;charset=UTF-8" /> 
        <title>ScopeJS: Pimp your lexical scopes.</title>
        <link rel="stylesheet" type="text/css" href="documentation/css/doc.css" /> 
        <link rel="shortcut icon" href="documentation/images/favicon.ico" /> 
      </head>
      <body>
        #{html}
      </body>
      </html>
      """
    
    fs.writeFileSync 'index.html', index
    

task 'install', 'install ScopeJS into /usr/local', (options) ->
  base = '/usr/local'
  lib  = "#{base}/lib/scope"
  node = "/usr/local/lib/node_modules/"
  console.log   "Installing ScopeJS to #{lib}"
  console.log   "Linking to #{node}"
  exec([
    "mkdir -p #{lib}"
    "cp -rf lib LICENSE README.md index.js package.json src #{lib}"
    "mkdir -p #{node}"
    "ln -sfn #{lib} #{node}"
  ].join(' && '), (err, stdout, stderr) ->
    if err then console.log stderr.trim() else log 'done', green
  )


task 'uninstall', 'uninstall ScopeJS from /usr/local', ->
  base = '/usr/local'
  lib  = "#{base}/lib/scope"
  node = "/usr/local/lib/node_modules"
  console.log   "Uninstall ScopeJS from #{lib}"
  console.log   "unlinking from #{node}"
  exec([
    "rm -rf #{lib}"
    "rm #{node}/scope"
  ].join(' && '), (err, stdout, stderr) ->
    if err then console.log stderr.trim() else log 'done', green
  )



# Prepare this project to run in the browser.
buildForBrowser = ({dir, out, init, vendor}) ->

  head = """
    (function() {
      var define = function(name, f) {
        return define[name] = f;
      };
      var pending = {};
      var require = function(name) {
        if(!require[name]) {
          if(pending[name]) throw 'Circular include';
          pending[name] = true;
          require[name] = new (define[name]);
          delete pending[name];
        }
        return require[name];
      };
    """

  tail = """
      #{init}
    })();
    """
  
  modules = ''
  for file in fs.readdirSync dir when m = file.match /(.*)\.coffee$/
    cs = fs.readFileSync path.join(dir, file), 'utf8'
    js = CoffeeScript.compile cs, bare: true
    modules += """
        define('./#{m[1]}', (function exports() {
        var exports = this;
        #{js}
        }));
        """
        
  for file in vendor or []
    js = fs.readFileSync path.join('vendor', "#{file}.js"), 'utf8'
    modules += """
      define('./../vendor/#{file}', (function exports() {
      var exports = this;
      #{js}
      }));
      """
    
  fs.writeFileSync out, head + modules + tail

task 'build', 'Build this project', ->
  exec "coffee -c -o lib src/*.coffee"
  #exec "docco src/*.coffee"
  buildForBrowser
    dir: 'src'
    out: path.join 'browser', 'scope.js'
    init: "this.Scope = require('./scope').Scope"
  runTests CoffeeScript, require './src/scope'
  
  ###
  cs = fs.readFileSync 'src/scope.coffee', 'utf8'
  m = cs.match /([\s\S]*)# END_README/
  fs.writeFileSync 'README.md', m[1].replace /# /g, ''
  ###
  
# Taken pretty-much intact from CoffeeScript's Cakefile
# Run the project's test suite.
runTests =  (CoffeeScript, scope) ->
  startTime   = Date.now()
  currentFile = null
  passedTests = 0
  failures    = []

  # make "global" reference available to tests
  global.global = global

  # Mix in the assert module globally, to make it available for tests.
  addGlobal = (name, func) ->
    global[name] = ->
      passedTests += 1
      func arguments...

  addGlobal name, func for name, func of require 'assert'

  # Convenience aliases.
  global.eq = global.strictEqual
  global.Scope = scope.Scope
  global.CoffeeScript = CoffeeScript
  
  # Our test helper function for delimiting different test cases.
  global.test = (description, fn) ->
    return unless fn
    try
      fn.test = {description, currentFile}
      fn.call(fn)
    catch e
      e.description = description if description?
      e.source      = fn.toString() if fn.toString?
      failures.push file: currentFile, error: e

  # A recursive functional equivalence helper; uses egal for testing equivalence.
  # See http://wiki.ecmascript.org/doku.php?id=harmony:egal
  arrayEqual = (a, b) ->
    if a is b
      # 0 isnt -0
      a isnt 0 or 1/a is 1/b
    else if a instanceof Array and b instanceof Array
      return no unless a.length is b.length
      return no for el, idx in a when not arrayEqual el, b[idx]
      yes
    else
      # NaN is NaN
      a isnt a and b isnt b

  global.arrayEq = (a, b, msg) -> ok arrayEqual(a,b), msg

  # When all the tests have run, collect and print errors.
  # If a stacktrace is available, output the compiled function source.
  process.on 'exit', ->
    time = ((Date.now() - startTime) / 1000).toFixed(2)
    message = "passed #{passedTests} tests in #{time} seconds#{reset}"
    return log(message, green) unless failures.length
    log "failed #{failures.length} and #{message}", red
    for fail in failures
      {error, file}      = fail
      jsFile             = file.replace(/\.coffee$/,'.js')
      match              = error.stack?.match(new RegExp(fail.file+":(\\d+):(\\d+)"))
      match              = error.stack?.match(/on line (\d+):/) unless match
      [match, line, col] = match if match
      log "\n  #{error.toString()}", red
      log "  #{error.description}", red if error.description
      log "  #{jsFile}: line #{line or 'unknown'}, column #{col or 'unknown'}", red
      console.log "  #{error.source}" if error.source

  # Run every test in the `test` folder, recording failures.
  fs.readdir 'test', (err, files) ->
    files.forEach (file) ->
      return unless file.match(/\.coffee$/i)
      filename = path.join 'test', file
      code = fs.readFileSync filename, 'utf8'
      currentFile = filename
      try
        CoffeeScript.run code.toString(), {filename}
      catch e
        failures.push file: currentFile, error: e


task 'test', "run the project's test-suite", ->
  runTests CoffeeScript, require './src/scope'

  
