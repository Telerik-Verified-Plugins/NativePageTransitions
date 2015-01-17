/**
 * This class automatically wires up your Ionic Framework project
 * to the Native Page Transitions plugin.
 *
 *
 * We scan the code on deviceready for any animation tags.
 * We expect a direction as well: animation="slide-left-right"
 * Slide default: left, Flip default: right.
 *
 * If you specify a default transitions, we will use that as the default as expected:
 * <body animation="slide-left-right">
 *
 * Prevent anchors (<a> tags) or back buttons from being auto-enhanced by adding:
 * animation-native="false" to the tag: <ion-nav-back-button animation-native="false">
 *
 * (untested feature:) To add a delay for ios or android, add:
 * animation-native-androiddelay="200" to the tag (200 ms for android in this case)
 *
 * TODO: add attributes for things like duration and slowdownfactor
 *
 *
 ************************************************************************************
 * PRO TIP: specify details in the $ionicPlatform.ready function of app.js:
 *
 *   window.plugins.nativepagetransitions.globalOptions.duration = 350;
 *   window.plugins.nativepagetransitions.globalOptions.slowdownfactor = 8;
 *   // window.plugins.nativepagetransitions.globalOptions.fixedPixelsTop = 64;
 *   window.plugins.nativepagetransitions.globalOptions.fixedPixelsBottom = 48;
 *
 */

(function () {

  "use strict";

  var transitionStack = [];
  var defaultTransition = null;

  // poor mans autowiring trigger.. we need dominserted stuff for enhancing dynamic links
  ionic.on("click", function (event) {
    // timeout because the dom needs to update before the buttons can be enhanced
    setTimeout(function () {
      window.NativePageTransitionsIonicAdapter.apply();
    }, 400);
  });

  var NativePageTransitionsIonicAdapter = function () {
    window.NativePageTransitionsIonicAdapter = this;
  };

  NativePageTransitionsIonicAdapter.prototype = {

    enhanceBackbuttons: function (from) {
      var backbuttons = document.querySelectorAll('button.back-button');
      for (var j = 0; j < backbuttons.length; j++) {
        var backbutton = backbuttons[j];
        if (backbutton.getAttribute("animation-native") !== "false") {
          var transition = transitionStack.pop() || "slide:right"; // default, when stack is empty
          var direction = transition.substring(transition.indexOf(":") + 1);
          if (transition.indexOf("flip") > -1) {
            backbutton.setAttribute("onclick", 'event.preventDefault ? event.preventDefault() : event.returnValue = false;');
            backbutton.setAttribute("ontouchend", 'event.preventDefault ? event.preventDefault() : event.returnValue = false; setTimeout(function(){window.kendo.mobile.application.pane.navigate("#:back")},20); window.NativePageTransitionsIonicAdapter.flip(\'' + direction + '\', \'' + from + '\', \'' + 100 + '\', \'' + 100 + '\')');
          } else {
            backbutton.setAttribute("onclick", 'event.stopPropagation(); event.preventDefault ? event.preventDefault() : event.returnValue = false;');
            backbutton.setAttribute("ontouchend", 'event.preventDefault ? event.preventDefault() : event.returnValue = false; window.NativePageTransitionsIonicAdapter.slide(\'' + direction + '\', \'' + from + '\', \'140\', \'140\')');
          }
        }
      }
    },

    apply: function () {
      if (defaultTransition == null) {
        defaultTransition = document.body.getAttribute("animation");
        if (defaultTransition == null) {
          defaultTransition = "none";
        }
      }

      var transAnchors;
      if (defaultTransition == "none") {
        // if there is no default, we only need to enhance the specific tags
        transAnchors = document.querySelectorAll("a[animation]");
      } else {
        // if there is a default, enhance all tags (except backbuttons and data-rel's (like modalview)), and honor the specific overrides if they exist
        transAnchors = document.querySelectorAll('a[href]:not([data-rel])');
        // add an animation attribute to all anchors without one, so the processing below is uniform
        for (var t = 0; t < transAnchors.length; t++) {
          var theAnchor = transAnchors[t];
          // exclude and links with window.open
          var lowerhref = theAnchor.getAttribute('href').toLowerCase();
          if (lowerhref.indexOf("window.open") == -1 && lowerhref.indexOf("url.loadurl") == -1) {
            if (!theAnchor.hasAttribute("animation")) {
              theAnchor.setAttribute("animation", defaultTransition);
            }
          }
        }
      }
      for (var i = 0; i < transAnchors.length; i++) {
        var transAnchor = transAnchors[i];
        if (transAnchor.getAttribute("animation-native") !== "false") {
          var transition = transAnchor.getAttribute("animation");
          if (transition != null && transition != "none") {
            var href = transAnchor.getAttribute("href");

            var androiddelay = transAnchor.getAttribute("animation-native-androiddelay");
            if (iosdelay == null) {
              iosdelay = 100;
            }
            var iosdelay = transAnchor.getAttribute("animation-native-iosdelay");
            if (iosdelay == null) {
              iosdelay = 100;
            }

            if (transition.indexOf("slide") > -1) {
              this._addSlideEvent(transAnchor, transition, href, androiddelay, iosdelay);
            } else if (transition.indexOf("flip") > -1) {
              this._addFlipEvent(transAnchor, transition, href, androiddelay, iosdelay);
            } else {
              // unsupported transition for now, so leave it be
              continue;
            }
            // removing these will prevent these element to be processed again in this lifecycle
            transAnchor.removeAttribute("animation");
            if (href != null) {
              transAnchor.removeAttribute("href");
            }
          }
        }
      }
    },

    _addSlideEvent: function (transAnchor, transition, href, androiddelay, iosdelay) {
      var direction = "left";
      if (transition.indexOf("slide-right") > -1) {
        direction = "right";
      } else if (transition.indexOf("slide-up") > -1) {
        direction = "up";
      } else if (transition.indexOf("slide-down") > -1) {
        direction = "down";
      }
      transAnchor.setAttribute("onclick", 'window.NativePageTransitionsIonicAdapter.slide(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    _addFlipEvent: function (transAnchor, transition, href, androiddelay, iosdelay) {
      var direction = "left";
      if (transition.indexOf("flip-right") > -1) {
        direction = "right";
      } else if (transition.indexOf("flip-up") > -1) {
        direction = "up";
      } else if (transition.indexOf("flip-down") > -1) {
        direction = "down";
      }
      transAnchor.setAttribute("onclick", 'window.NativePageTransitionsIonicAdapter.flip(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    getOppositeDirection: function (direction) {
      if (direction == "right") {
        return "left";
      } else if (direction == "up") {
        return "down";
      } else if (direction == "down") {
        return "up";
      } else {
        return "right";
      }
    },

    slide: function (direction, href, androiddelay, iosdelay) {
      event.preventDefault ? event.preventDefault() : event.returnValue = false;
      transitionStack.push("slide:" + this.getOppositeDirection(direction));
      window.plugins.nativepagetransitions.slide({
            'direction': direction,
            'androiddelay': androiddelay,
            'iosdelay': iosdelay,
//            'winphonedelay': winphonedelay,
            'href': href
          },
          function () {
            console.log('slide transition finished');
          },
          function (errmsg) {
            console.log('slide transition failed: ' + errmsg);
          });
    },

    flip: function (direction, href, androiddelay, iosdelay) {
      event.preventDefault ? event.preventDefault() : event.returnValue = false;
      transitionStack.push("flip:" + this.getOppositeDirection(direction));
      window.plugins.nativepagetransitions.flip({
            'direction': direction,
            'androiddelay': androiddelay,
            'iosdelay': iosdelay,
//            'winphonedelay': winphonedelay,
            'href': href
          },
          function () {
            console.log('flip transition finished');
          },
          function (errmsg) {
            console.log('flip transition failed: ' + errmsg);
          });
    }
  };

  var adapter = new NativePageTransitionsIonicAdapter();

  // wait for cordova (and its plugins) to be ready
  document.addEventListener(
      "deviceready",
      function () {
        if (window.ionic && window.plugins && window.plugins.nativepagetransitions) {
          adapter.apply();
          adapter.enhanceBackbuttons();

          window.ionic.on("hashchange", function (event) {
            // timeout because the dom needs to update before the buttons can be enhanced
            var from = event.oldURL.substring(event.oldURL.indexOf("#"));
            setTimeout(function () {
              window.NativePageTransitionsIonicAdapter.enhanceBackbuttons(from);
            }, 100);
          });

        } else {
          console.log("window.plugins.nativepagetransitions is not available, so no native transitions will be applied");
        }
      },
      false);
})();
