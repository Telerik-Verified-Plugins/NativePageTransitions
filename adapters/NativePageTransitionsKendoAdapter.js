/**
 * This class automatically wires up your KendoUI Mobile project
 * to the Native Page Transitions plugin.
 *
 * We scan the code on deviceready for any data-transition tags.
 * We expect a direction as well: data-transition="slide:left"
 * If no direction is set, a default is used: data-transition="slide".
 * Slide default: left, Flip default: right.
 *
 * If you specify a default transitions, we will use that as the default as expected:
 * new kendo.mobile.Application(document.body, {transition: 'slide'});
 *
 * Prevent anchors (<a> tags) from being auto-enhanced by adding:
 * data-transition-native="false" to the tag.
 *
 * To add a delay for ios or android, add:
 * data-transition-native-androiddelay="200" to the tag (200 ms for android in this case)
 *
 * TODO: add data- attributes for things like duration and slowdownfactor
 * TODO: auto-enhance drawers based on data-rel="drawer" & data-align="right"
 * TODO: add support for remote views
 */

(function() {

  "use strict";

  var transitionStack = [];
  var defaultTransition = null;

  window.addEventListener('hashchange', function(hashchangeevent) {
    // timeout because the dom needs to update before the backbutton can be enhanced
    setTimeout(function() {
      window.NativePageTransitionsKendoAdapter.enhanceBackbuttons();
    }, 100);
  });

  var NativePageTransitionsKendoAdapter = function() {
    window.NativePageTransitionsKendoAdapter = this;
  };

  NativePageTransitionsKendoAdapter.prototype = {

    enhanceBackbuttons : function() {
      // find all views..
      var backbuttonViews = document.querySelectorAll('div[data-role="view"]');
      for (var i = 0; i < backbuttonViews.length; i++) {
        var backbuttonView = backbuttonViews[i];
        // find the view which is currently showing (not hidden)
        if (backbuttonView.style.display != "none") {
          var backbuttons = backbuttonView.querySelectorAll('a[data-role="backbutton"]');
          for (var j = 0; j < backbuttons.length; j++) {
            var backbutton = backbuttons[j];
            if (backbutton.getAttribute("data-transition-native") !== "false") {
              var transition = transitionStack.pop() || "slide:right";
              if (transition.indexOf("flip") > -1) {
                backbutton.setAttribute("ontouchend", 'event.preventDefault(); setTimeout(function(){window.kendo.mobile.application.pane.navigate("#:back")},20); window.NativePageTransitionsKendoAdapter.flip(\'right\', null, \'' + 100 + '\', \'' + 100 + '\')');
              } else {
                backbutton.setAttribute("ontouchend", 'event.preventDefault(); setTimeout(function(){window.kendo.mobile.application.pane.navigate("#:back")},20); window.NativePageTransitionsKendoAdapter.slide(\'right\', null, \'' + 140 + '\', \'' + 140 + '\')');
              }
            }
          }
          return false; // found the right view, so break the loop
        }
      }
    },

    apply : function () {
      if (this._checkPluginLoaded() && window.kendo.mobile.application) {

        if (defaultTransition == null) {
          // figure out the default transition and use that as our default
          defaultTransition = window.kendo.mobile.application.options.transition;
          if (defaultTransition == "") {
            defaultTransition = "none";
          }
          // make sure the Kendo transitions don't interfere with ours by disabling them
          window.kendo.effects.enabled = false;
        }

        // enhance <a> tags
        var transAnchors;
        if (defaultTransition == "none") {
          // if there is no default, we only need to enhance the specific tags
          transAnchors = document.querySelectorAll("a[data-transition]");
        } else {
          // if there is a default, enhance all tags (except backbuttons and data-rel's (like modalview)), and honor the specific overrides if they exist
          transAnchors = document.querySelectorAll('a[href]:not([data-role="backbutton"]):not([data-rel])');
          // add a data-transition attribute to all anchors without one, so the processing below is uniform
          for (var t = 0; t < transAnchors.length; t++) {
            var theAnchor = transAnchors[t];
            if (!theAnchor.hasAttribute("data-transition")) {
              theAnchor.setAttribute("data-transition", defaultTransition);
            }
          }
        }
        for (var i = 0; i < transAnchors.length; i++) {
          var transAnchor = transAnchors[i];
          if (transAnchor.getAttribute("data-transition-native") !== "false") {
            var transition = transAnchor.getAttribute("data-transition");
            if (transition != null && transition != "none") {
              var href = transAnchor.getAttribute("href");

              // Kendo remote view support (work in progress, call the plugin directly for now, without a href param)
              // if (href.indexOf("#")==-1 && href.indexOf(".") > -1) {
              //   href = "#" + href.substr(0, href.indexOf("."));
              // }

              var androiddelay = transAnchor.getAttribute("data-transition-native-androiddelay");
              var iosdelay = transAnchor.getAttribute("data-transition-native-iosdelay");

              if (transition.indexOf("slide") > -1) {
                this._addSlideEvent(transAnchor, transition, href, androiddelay, iosdelay);
              } else if (transition.indexOf("flip") > -1) {
                this._addFlipEvent(transAnchor, transition, href, androiddelay, iosdelay);
              } else {
                // unsupported transition for now, so leave it be
                continue;
              }
              // removing these will prevent these element to be processed again in this lifecycle
              transAnchor.removeAttribute("href");
              transAnchor.removeAttribute("data-transition");
            }
          }
        }
      }
    },

    _addSlideEvent : function (transAnchor, transition, href, androiddelay, iosdelay) {
      var direction = "left"; // define a default
      if (transition.indexOf("slide:") > -1) {
        direction = transition.substring(6);
      }
      // note: for WinPhone we should not use ontouchend
      transAnchor.setAttribute("onclick", 'window.NativePageTransitionsKendoAdapter.slide(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    _addFlipEvent : function (transAnchor, transition, href, androiddelay, iosdelay) {
      var direction = "right"; // define a default
      if (transition.indexOf("flip:") > -1) {
        direction = transition.substring(5);
      }
      // note: for WinPhone we should not use ontouchend
      transAnchor.setAttribute("onclick", 'window.NativePageTransitionsKendoAdapter.flip(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    slide : function (direction, href, androiddelay, iosdelay) {
      event.preventDefault();
      transitionStack.push("slide:" + (direction == 'left' ? 'right' : 'left'));
      window.plugins.nativepagetransitions.slide({
            'direction': direction,
            'androiddelay': androiddelay,
            'iosdelay': iosdelay,
            'href': href
          },
          function () {
            console.log('slide transition finished');
          },
          function (errmsg) {
            console.log('slide transition failed: ' + errmsg);
          });
    },

    flip : function (direction, href, androiddelay, iosdelay) {
      event.preventDefault();
      transitionStack.push("flip:" + (direction == 'right' ? 'left' : 'right'));
      window.plugins.nativepagetransitions.flip({
            'direction': direction,
            'androiddelay': androiddelay,
            'iosdelay': iosdelay,
            'href': href
          },
          function () {
            console.log('flip transition finished');
          },
          function (errmsg) {
            console.log('flip transition failed: ' + errmsg);
          });
    },

    _checkPluginLoaded : function () {
      if (window.plugins && window.plugins.nativepagetransitions) {
        return true;
      } else {
        console.log("window.plugins.nativepagetransitions is not available, so no native transitions will be applied");
        return false;
      }
    }
  };

  // wait for cordova (and its plugins) to be ready
  document.addEventListener(
      "deviceready",
      function() {
        new NativePageTransitionsKendoAdapter().apply();

        // listen for elements with a-tags added to the dom
        var dispatchIndex = 0;
        document.body.addEventListener("DOMNodeInserted", function() {
          var target = event.relatedNode;
          var addedAnchors = target.getElementsByTagName("a");
          if (addedAnchors.length > 0) {
            var thisIndex = ++dispatchIndex;
            setTimeout(function () {
              // enhance the anchors if there is no newer pending event within this timeout
              if (dispatchIndex == thisIndex) {
                window.NativePageTransitionsKendoAdapter.apply();
                console.log("--------- enhancing for index: " + thisIndex);
              }
            }, 20);
          }
        }, true);
      },
      false);
})();