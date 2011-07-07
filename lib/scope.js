(function() {
  /*
   * Scopejs v0.10.1
   * http://scopejs.org
   *
   * Copyright(c) 2011 Derek Brans <dbrans@gmail.com>
   * Released under the MIT License
  */
  var COFFEESCRIPT_HELPERS, Scope, extend, isFn, isString;
  var __slice = Array.prototype.slice, __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  isString = function(x) {
    return !!(x === '' || (x && x.charCodeAt && x.substr));
  };
  isFn = function(x) {
    return !!(x && x.constructor && x.call && x.apply);
  };
  extend = function() {
    var k, more, o, v, x, _i, _len;
    x = arguments[0], more = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    for (_i = 0, _len = more.length; _i < _len; _i++) {
      o = more[_i];
      for (k in o) {
        v = o[k];
        x[k] = v;
      }
    }
    return x;
  };
  exports.COFFEESCRIPT_HELPERS = COFFEESCRIPT_HELPERS = {
    "__slice": Array.prototype.slice,
    "__bind": function(fn, me) {
      return function() {
        return fn.apply(me, arguments);
      };
    },
    "__indexOf": Array.prototype.indexOf || function(item) {
      var i, x;
      if ((function() {
        var _len, _results;
        _results = [];
        for (i = 0, _len = this.length; i < _len; i++) {
          x = this[i];
          _results.push(x === item);
        }
        return _results;
      }).call(this)) {
        return i;
      }
    },
    "__hasProp": Object.prototype.hasOwnProperty,
    "__extends": function(child, parent) {
      var ctor, key, _results;
      _results = [];
      for (key in parent) {
        if (eval('__hasProp').call(parent, key)) {
          child[key] = parent[key];
        }
        ctor = function() {
          return this.constructor = child;
        };
        ctor.prototype = parent.prototype;
        child.prototype = new ctor;
        child.__super__ = parent.prototype;
        _results.push(child);
      }
      return _results;
    }
  };
  exports.Scope = Scope = (function() {
    var EVAL_LITERAL, literalize;
    EVAL_LITERAL = "(function(__expr){return eval(__expr)})";
    Scope._eval = (1, eval)(EVAL_LITERAL);
    Scope.eval = function(context, expr, literalize_) {
      var literals, locals, name, val, _ref;
      if (literalize_ == null) {
        literalize_ = literalize;
      }
      if (expr == null) {
        _ref = [null, context], context = _ref[0], expr = _ref[1];
      }
      locals = (context != null ? context.locals : void 0) && ((function() {
        var _results;
        _results = [];
        for (name in context.locals) {
          _results.push("var " + name + " = this.locals." + name + ";\n");
        }
        return _results;
      })()).join('') || "";
      literals = (context != null ? context.literals : void 0) && ((function() {
        var _ref2, _results;
        _ref2 = context.literals;
        _results = [];
        for (name in _ref2) {
          val = _ref2[name];
          _results.push("var " + name + " = " + (literalize(val)) + ";\n");
        }
        return _results;
      })()).join('') || "";
      return this._eval.call(context, locals + literals + literalize_(expr));
    };
    Scope.run = function(ctx, fn) {
      return this.eval(ctx, fn, function(fn) {
        return "" + (literalize(fn)) + ".call(this)";
      });
    };
    Scope.literalize = literalize = function(x) {
      if (isString(x)) {
        return x;
      } else if (isFn(x)) {
        x = x.toString();
        x = x.replace(/function[^\(]*\(/, "function (");
        return "(" + x + ")";
      } else {
        return x.literal();
      }
    };
    Scope.reserved = ['__expr'];
    Scope.makeGetter = function(name) {
      return function() {
        return this.get(name);
      };
    };
    Scope.makeSetter = function(name) {
      return function(val) {
        return this.set(name, val, false);
      };
    };
    Scope.root = new Scope({
      locals: COFFEESCRIPT_HELPERS
    });
    Scope.create = function(options) {
      if (options == null) {
        options = {};
      }
      return this.root.extend(options);
    };
    function Scope(options) {
      var C, exports, k, n, name, names, varTypes, x, _base, _i, _j, _k, _l, _len, _len2, _len3, _len4, _len5, _len6, _m, _n, _ref, _ref2;
      this.options = options != null ? options : {};
      varTypes = ['locals', 'literals'];
      for (_i = 0, _len = varTypes.length; _i < _len; _i++) {
        k = varTypes[_i];
                if ((_ref = (_base = this.options)[k]) == null) {
          _base[k] = {};
        };
      }
      this.options.locals.__this = this;
      this.parent = this.options.parent;
      names = [];
      for (_j = 0, _len2 = varTypes.length; _j < _len2; _j++) {
        k = varTypes[_j];
        for (name in this.options[k]) {
          names.push(name);
        }
      }
      for (_k = 0, _len3 = names.length; _k < _len3; _k++) {
        n = names[_k];
        if (__indexOf.call(this.constructor.reserved, n) >= 0) {
          throw 'Reserved';
        }
      }
      this.names = names.concat(((_ref2 = this.parent) != null ? _ref2.names : void 0) || []);
      this._eval = (this.parent || Scope).eval(this.options, EVAL_LITERAL);
      exports = (function() {
        var _l, _len4, _ref3, _results;
        _ref3 = this.names;
        _results = [];
        for (_l = 0, _len4 = _ref3.length; _l < _len4; _l++) {
          x = _ref3[_l];
          if (!x.match(/^_/)) {
            _results.push(x);
          }
        }
        return _results;
      }).call(this);
      for (_l = 0, _len4 = exports.length; _l < _len4; _l++) {
        x = exports[_l];
        if (x in this) {
          throw 'Name collision';
        }
      }
      C = this.constructor;
      if (this.__defineGetter__ != null) {
        for (_m = 0, _len5 = exports.length; _m < _len5; _m++) {
          x = exports[_m];
          this.__defineGetter__(x, C.makeGetter(x));
          this.__defineSetter__(x, C.makeSetter(x));
        }
      } else {
        for (_n = 0, _len6 = exports.length; _n < _len6; _n++) {
          x = exports[_n];
          this[x] = C.makeGetter(x).call(this);
        }
      }
    }
    Scope.prototype.eval = Scope.eval;
    Scope.prototype.run = Scope.run;
    Scope.prototype.self = function(f) {
      return f.call(this);
    };
    Scope.prototype.set = function(name, val, isLiteral) {
      var obj, _len, _ref, _results;
      if (isString(name)) {
        return this._eval.call({
          val: val
        }, ("" + name + " = ") + (isLiteral ? literalize(val) : "this.val"));
      } else {
        _ref = [name, val], obj = _ref[0], isLiteral = _ref[1];
        _results = [];
        for (val = 0, _len = obj.length; val < _len; val++) {
          name = obj[val];
          _results.push(this.set(name, val, isLiteral));
        }
        return _results;
      }
    };
    Scope.prototype.get = function(name) {
      return this._eval(name);
    };
    Scope.prototype.extend = function(options) {
      if (options == null) {
        options = {};
      }
      return new (options["class"] || this.constructor)(extend(options, {
        parent: this
      }));
    };
    return Scope;
  })();
}).call(this);
