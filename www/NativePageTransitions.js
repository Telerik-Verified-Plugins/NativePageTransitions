function NativePageTransitions() {
}

NativePageTransitions.prototype.slide = function (options, onSuccess, onError) {
  var opts = options || {};
  opts.direction = opts.direction || "left";
  opts.duration = opts.duration || 500;
  opts.androiddelay = opts.androiddelay || 50;
  opts.iosdelay = opts.iosdelay || 0;
  // setting slowdownfactor > 1 makes the next page slide less pixels.
  // Try 3 for a nice effect, especially on iOS.
  opts.slowdownfactor  = opts.slowdownfactor || 1;
  cordova.exec(onSuccess, onError, "NativePageTransitions", "slide", [opts]);
};

NativePageTransitions.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }

  window.plugins.nativepagetransitions = new NativePageTransitions();
  return window.plugins.nativepagetransitions;
};

cordova.addConstructor(NativePageTransitions.install);