function NativePageTransitions() {
}

NativePageTransitions.prototype.slide = function (options, onSuccess, onError) {
  var opts = options || {};
  opts.direction = opts.direction || "left";
  opts.duration = opts.duration || 400;
  opts.androiddelay = opts.androiddelay || 50;
  opts.iosdelay = opts.iosdelay || 50;
  // setting slowdownfactor > 1 makes the next page slide less pixels. Use 1 for side-by-side.
  opts.slowdownfactor = opts.slowdownfactor || 3;
  cordova.exec(onSuccess, onError, "NativePageTransitions", "slide", [opts]);
};

NativePageTransitions.prototype.drawer = function (options, onSuccess, onError) {
  var opts = options || {};
  opts.origin = opts.origin || "left";
  opts.action = opts.action || "open";
  opts.duration = opts.duration || 400;
  opts.androiddelay = opts.androiddelay || 50;
  opts.iosdelay = opts.iosdelay || 50;
  cordova.exec(onSuccess, onError, "NativePageTransitions", "drawer", [opts]);
};

NativePageTransitions.prototype.flip = function (options, onSuccess, onError) {
  var opts = options || {};
  opts.direction = opts.direction || "right";
  opts.duration = opts.duration || 400;
  opts.androiddelay = opts.androiddelay || 50;
  opts.iosdelay = opts.iosdelay || 50;
  cordova.exec(onSuccess, onError, "NativePageTransitions", "flip", [opts]);
};

NativePageTransitions.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }

  window.plugins.nativepagetransitions = new NativePageTransitions();
  return window.plugins.nativepagetransitions;
};

cordova.addConstructor(NativePageTransitions.install);