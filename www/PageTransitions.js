function PageTransitions() {
}

PageTransitions.prototype.slide = function (options, onSuccess, onError) {
  var opts = options || {};
  opts.direction = opts.direction || "left";
  opts.duration = opts.duration || 500;
  opts.androiddelay = opts.androiddelay || 50;
  opts.iosdelay = opts.iosdelay || 0;
  // setting slowdownfactor > 1 makes the next page slide less pixels.
  // Try 3 for a nice effect, especially on iOS.
  opts.slowdownfactor  = opts.slowdownfactor || 1;
  cordova.exec(onSuccess, onError, "PageTransitions", "slide", [opts]);
};

PageTransitions.install = function () {
  if (!window.plugins) {
    window.plugins = {};
  }

  window.plugins.pagetransitions = new PageTransitions();
  return window.plugins.pagetransitions;
};

cordova.addConstructor(PageTransitions.install);