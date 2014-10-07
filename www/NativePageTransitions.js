function NativePageTransitions() {
}

NativePageTransitions.prototype.slide = function (options, onSuccess, onError) {
  var opts = options || {};
  if (!this._validateHref(opts.href, onError)) {
    return;
  }
  opts.direction = opts.direction || "left";
  if (opts.duration == undefined || opts.duration == "null") {
    opts.duration = 400;
  }
  if (opts.androiddelay == undefined || opts.androiddelay == "null") {
    opts.androiddelay = 50;
  }
  if (opts.iosdelay == undefined || opts.iosdelay == "null") {
    opts.iosdelay = 50;
  }
  // setting slowdownfactor > 1 makes the next page slide less pixels. Use 1 for side-by-side.
  opts.slowdownfactor = opts.slowdownfactor || 3;
  cordova.exec(onSuccess, onError, "NativePageTransitions", "slide", [opts]);
};

NativePageTransitions.prototype.drawer = function (options, onSuccess, onError) {
  var opts = options || {};
  if (!this._validateHref(opts.href, onError)) {
    return;
  }
  opts.origin = opts.origin || "left";
  opts.action = opts.action || "open";
  if (opts.duration == undefined || opts.duration == "null") {
    opts.duration = 400;
  }
  if (opts.androiddelay == undefined || opts.androiddelay == "null") {
    opts.androiddelay = 50;
  }
  if (opts.iosdelay == undefined || opts.iosdelay == "null") {
    opts.iosdelay = 50;
  }
  cordova.exec(onSuccess, onError, "NativePageTransitions", "drawer", [opts]);
};

NativePageTransitions.prototype.flip = function (options, onSuccess, onError) {
  var opts = options || {};
  if (!this._validateHref(opts.href, onError)) {
    return;
  }
  opts.direction = opts.direction || "right";
  if (opts.duration == undefined || opts.duration == "null") {
    opts.duration = 400;
  }
  if (opts.androiddelay == undefined || opts.androiddelay == "null") {
    opts.androiddelay = 50;
  }
  if (opts.iosdelay == undefined || opts.iosdelay == "null") {
    opts.iosdelay = 50;
  }
  cordova.exec(onSuccess, onError, "NativePageTransitions", "flip", [opts]);
};

NativePageTransitions.prototype._validateHref = function (href, errCallback) {
  var currentHref = window.location.href.substr(window.location.href.indexOf('www/')+4);
  // if no href was passed the transition should always kick in
  if (href) {
    if (href.indexOf('#') == 0) {
      // starts with a #, so check if the current one has a hash with the same value
      if (currentHref.indexOf('#') > -1) {
        currentHref = currentHref.substr(currentHref.indexOf('#'));
      }
    }
  }
  if (currentHref == href) {
    if (errCallback) {
      errCallback("The passed href is the same as the current");
    } else {
      console.log("The passed href is the same as the current");
    }
    return false;
  }
  return true;
};

NativePageTransitions.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }

  window.plugins.nativepagetransitions = new NativePageTransitions();
  return window.plugins.nativepagetransitions;
};

cordova.addConstructor(NativePageTransitions.install);