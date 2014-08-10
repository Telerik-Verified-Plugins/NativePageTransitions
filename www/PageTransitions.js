function PageTransitions() {
}

PageTransitions.prototype.slide = function (options, onSuccess, onError) {
  var opts = options || {};
  opts.direction = opts.direction || "left";
  opts.duration  = opts.duration  || 700;
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