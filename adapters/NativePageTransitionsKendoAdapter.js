/**
 * This class automatically wires up your KendoUI Mobile project
 * to the Native Page Transitions plugin.
 *
 * We scan the code on deviceready for any data-transition tags.
 * We expect a direction as well: data-transition="slide:left"
 * If no direction is set, a default is used: data-transition="slide".
 * Slide default: left, Flip default: right.
 *
 * You should not define default transitions when creating your Kendo App, so:
 * new kendo.mobile.Application(document.body, {transition: 'slide'}); // don't do this
 * new kendo.mobile.Application(document.body); // but do this instead
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

  var previousPageHrefStack = [];
  var transitionStack = [];
  var observerAdded = false;

  window.addEventListener('hashchange', function(hashchangeevent) {
    var href = hashchangeevent.oldURL.substr(hashchangeevent.oldURL.indexOf('www/')+4);
    previousPageHrefStack.push(href);
    // the dom needs to update before the backbutton can be enhanced
    setTimeout(function() {
      window.NativePageTransitionsKendoAdapter.enhanceBackbuttons();
    }, 30);
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
              var href = previousPageHrefStack.pop() || "index.html";
              var transition = transitionStack.pop() || "slide:right";
              if ("flip" == transition) {
                this._addFlipEvent(backbutton, transition, href, 50, 50);
              } else {
                this._addSlideEvent(backbutton, transition, href, 50, 50);
              }
              backbutton.removeAttribute("href"); // note that this removes the link style
              backbutton.removeAttribute("data-transition");
            }
          }
          return false; // found the right view, so break the loop
        }
      }
    },

    apply : function () {
      if (this._checkPluginLoaded()) {

        if (!observerAdded) {
          observerAdded = true;
          observer.observe(document, {
            childList: true,
            subtree: true,
            attributes: false
          });
        }

        // enhance <a data-transition=""> tags
        var transAnchors = document.querySelectorAll("a[data-transition]");
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
      transAnchor.setAttribute("ontouchend", 'window.NativePageTransitionsKendoAdapter.slide(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    _addFlipEvent : function (transAnchor, transition, href, androiddelay, iosdelay) {
      var direction = "right"; // define a default
      if (transition.indexOf("flip:") > -1) {
        direction = transition.substring(5);
      }
      // note: for WinPhone we should not use ontouchend
      transAnchor.setAttribute("ontouchend", 'window.NativePageTransitionsKendoAdapter.flip(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
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

  // observe mutations to the Dom so dynamic views can be enhanced
  var MutationObserver = window.MutationObserver || window.WebKitMutationObserver;
  var observer = new MutationObserver(function(mutations, observer) {
    if (mutations[0].addedNodes.length || mutations[0].removedNodes.length) {
      console.log("Observed DOM change, so applying native transitions adapter");
      setTimeout(function () {
        window.NativePageTransitionsKendoAdapter.apply();
      }, 10);
    }
  });

  // wait for cordova (and its plugins) to be ready
  document.addEventListener(
      "deviceready",
      function(){new NativePageTransitionsKendoAdapter().apply()},
      false);
})();