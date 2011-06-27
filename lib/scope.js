(function() {
  /*
   * Scopejs v0.8.0
   * http://scopejs.org
   *
   * Copyright(c) 2011 Derek Brans <dbrans@gmail.com>
   * Released under the MIT License
  */
  var Scope, extend, isFn, isString;
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
  exports.Scope = Scope = (function() {
    var EVAL_LITERAL, literalize;
    EVAL_LITERAL = "(function(__expr){return eval(__expr)})";
    Scope.eval = (1, eval)(EVAL_LITERAL);
    Scope.literalize = literalize = function(x) {
      if (isString(x)) {
        return x;
      } else if (isFn(x)) {
        x = x.toString();
        x = x.replace(/function[^\(]*\(/, "function (");
        return "(" + x + ")";
      } else {
        return x.literalize();
      }
    };
    Scope.rootLocals = {
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
    Scope.initialize = function() {
      this.global = new this();
      return this.root = this.global.extend({
        locals: this.rootLocals
      });
    };
    Scope.create = function(options) {
      return this.root.extend(options);
    };
    function Scope(options) {
      var C, exports, k, literals, n, name, names, val, varTypes, x, _base, _i, _j, _k, _l, _len, _len2, _len3, _len4, _len5, _len6, _m, _n, _ref, _ref2;
      this.options = options != null ? options : {};
      varTypes = ['locals', 'literals'];
      for (_i = 0, _len = varTypes.length; _i < _len; _i++) {
        k = varTypes[_i];
                if ((_ref = (_base = this.options)[k]) == null) {
          _base[k] = {};
        };
      }
      this.options.locals.__scope = this;
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
      this._eval = this.parent == null ? Scope.eval : (literals = ((function() {
        var _ref3, _results;
        _ref3 = this.options.literals;
        _results = [];
        for (name in _ref3) {
          val = _ref3[name];
          _results.push("var " + name + " = " + (literalize(val)) + ";\n");
        }
        return _results;
      }).call(this)).join(''), this.parent.eval(this.options, literals + EVAL_LITERAL));
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
          this[x] = C.makeGetter(x)();
        }
      }
    }
    Scope.prototype.eval = function(ctx, expr) {
      var locals, name, _ref;
      if (!expr) {
        _ref = [{}, ctx], ctx = _ref[0], expr = _ref[1];
      }
      locals = ctx.locals ? ((function() {
        var _results;
        _results = [];
        for (name in ctx.locals) {
          _results.push("var " + name + " = this.locals." + name + ";\n");
        }
        return _results;
      })()).join('') : "";
      return this._eval.call(ctx, locals + literalize(expr));
    };
    Scope.prototype.run = function(ctx, fn) {
      var _ref;
      if (!fn) {
        _ref = [{}, ctx], ctx = _ref[0], fn = _ref[1];
      }
      return this.eval(ctx, "" + (literalize(fn)) + ".call(this)");
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
      return new this.constructor(extend(options, {
        parent: this
      }));
    };
    Scope.initialize();
    return Scope;
  })();
}).call(this);
