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
 * To enable transitions for links in remote views, you must add the data-transition attribute to those links.
 *
 * TODO: add data- attributes for things like duration and slowdownfactor
 * TODO: auto-enhance drawers based on data-rel="drawer" & data-align="right"
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
          var backbuttons = backbuttonView.querySelectorAll('a[data-role="backbutton"]:not([data-rel])');
          for (var j = 0; j < backbuttons.length; j++) {
            var backbutton = backbuttons[j];
            var href = backbutton.getAttribute("href");
            if (href != null && backbutton.getAttribute("data-transition-native") !== "false") {
              var transition = transitionStack.pop() || "slide:right";
              if (href == "#:back") {
                if (transition.indexOf("flip") > -1) {
                  backbutton.setAttribute("onclick", 'event.preventDefault ? event.preventDefault() : event.returnValue = false;');
                  backbutton.setAttribute("ontouchend", 'event.preventDefault ? event.preventDefault() : event.returnValue = false; setTimeout(function(){window.kendo.mobile.application.pane.navigate("#:back")},20); window.NativePageTransitionsKendoAdapter.flip(\'right\', null, \'' + 100 + '\', \'' + 100 + '\')');
                } else {
                  backbutton.setAttribute("onclick", 'event.preventDefault ? event.preventDefault() : event.returnValue = false;');
                  backbutton.setAttribute("ontouchend", 'event.preventDefault ? event.preventDefault() : event.returnValue = false; setTimeout(function(){window.kendo.mobile.application.pane.navigate("#:back")},20); window.NativePageTransitionsKendoAdapter.slide(\'right\', null, \'' + 140 + '\', \'' + 140 + '\')');
                }
              } else {
                // this branch is for remote views
                if (href.indexOf("#") == -1) {
                  href = "#" + href;
                }
                if (transition.indexOf("flip") > -1) {
                  backbutton.setAttribute("onclick", 'event.preventDefault ? event.preventDefault() : event.returnValue = false;');
                  backbutton.setAttribute("ontouchend", 'event.preventDefault ? event.preventDefault() : event.returnValue = false; window.NativePageTransitionsKendoAdapter.flip(\'right\', \''+href+'\', \'' + 100 + '\', \'' + 100 + '\')');
                } else {
                  backbutton.setAttribute("onclick", 'event.preventDefault ? event.preventDefault() : event.returnValue = false;');
                  backbutton.setAttribute("ontouchend", 'event.preventDefault ? event.preventDefault() : event.returnValue = false; window.NativePageTransitionsKendoAdapter.slide(\'right\', \''+href+'\', \'' + 140 + '\', \'' + 140 + '\')');
                }
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

        // hijack programmatic navigation
        if (!window.originalAppNavigate) {
          window.originalAppNavigate = window.app.navigate;
          window.app.navigate = function (href, transition) {
            if (href.charAt(0) !== '#') {
                //if remote view with no # prefix, prepend it
                href = '#' + href;
            }
            if (transition === undefined) {
              transition = defaultTransition;
            }
            if (transition === undefined) {
              transition = "slide";
            }
            if (transition.indexOf("flip") > -1) {
              var direction = "right"; // define a default
              if (transition.indexOf("flip:") > -1) {
                direction = transition.substring(5);
              }
              window.NativePageTransitionsKendoAdapter.flip(direction, href);
            } else if (transition.indexOf("slide") > -1) {
              var direction = "left"; // define a default
              if (transition.indexOf("slide:") > -1) {
                direction = transition.substring(6);
              }
              window.NativePageTransitionsKendoAdapter.slide(direction, href);
            } else {
              // unsupported by the adapter, invoke the original function
              window.originalAppNavigate(href, transition);
            }
          }
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
            // exclude and links with window.open
            var lowerhref = theAnchor.getAttribute('href').toLowerCase();
            if (lowerhref.indexOf("window.open") == -1 && lowerhref.indexOf("url.loadurl") == -1) {
              if (!theAnchor.hasAttribute("data-transition")) {
                theAnchor.setAttribute("data-transition", defaultTransition);
              }
            }
          }
        }
        for (var i = 0; i < transAnchors.length; i++) {
          var transAnchor = transAnchors[i];
          if (transAnchor.getAttribute("data-transition-native") !== "false") {
            var transition = transAnchor.getAttribute("data-transition");
            if (transition != null && transition != "none") {
              var href = transAnchor.getAttribute("href");

              if (href != null) {
                // Kendo remote view support
                if (href.indexOf("#") == -1 && href.indexOf(".") > -1) {
                  href = "#" + href;
                }
              }

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
              if (href != null) {
                transAnchor.removeAttribute("href");
              }
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
      transAnchor.setAttribute("onclick", 'window.NativePageTransitionsKendoAdapter.slide(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    _addFlipEvent : function (transAnchor, transition, href, androiddelay, iosdelay) {
      var direction = "right"; // define a default
      if (transition.indexOf("flip:") > -1) {
        direction = transition.substring(5);
      }
      transAnchor.setAttribute("onclick", 'window.NativePageTransitionsKendoAdapter.flip(\'' + direction + '\', \'' + href + '\', \'' + androiddelay + '\', \'' + iosdelay + '\')');
    },

    slide : function (direction, href, androiddelay, iosdelay) {
      event.preventDefault ? event.preventDefault() : event.returnValue = false;
      transitionStack.push("slide:" + (direction == 'left' ? 'right' : 'left'));
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

    flip : function (direction, href, androiddelay, iosdelay) {
      event.preventDefault ? event.preventDefault() : event.returnValue = false;
      transitionStack.push("flip:" + (direction == 'right' ? 'left' : 'right'));
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
    },

    _checkPluginLoaded : function () {
      if (window.plugins && window.plugins.nativepagetransitions) {
        return true;
      } else {
        console.log("window.plugins.nativepagetransitions is not available, so no native transitions will be applied");
        return false;
      }
    },

    // inlined minified version of fastclick, needed because we bind to onclick which has a delay
    loadFastClick : function() {
      if (!window.FastClick && !window.Origami) {
        /*
         FastClick: polyfill to remove click delays on browsers with touch UIs.
         @version 1.0.3
         @codingstandard ftlabs-jsv2
         @copyright The Financial Times Limited [All Rights Reserved]
         @license MIT License
         */
        (function e$$0(g,m,b){function h(f,k){if(!m[f]){if(!g[f]){var a="function"==typeof require&&require;if(!k&&a)return a(f,!0);if(e)return e(f,!0);a=Error("Cannot find module '"+f+"'");throw a.code="MODULE_NOT_FOUND",a;}a=m[f]={exports:{}};g[f][0].call(a.exports,function(a){var d=g[f][1][a];return h(d?d:a)},a,a.exports,e$$0,g,m,b)}return m[f].exports}for(var e="function"==typeof require&&require,k=0;k<b.length;k++)h(b[k]);return h})({1:[function(n,g,m){function b(a,c){function d(a,c){return function(){return a.apply(c,
        arguments)}}var l;c=c||{};this.trackingClick=!1;this.trackingClickStart=0;this.targetElement=null;this.lastTouchIdentifier=this.touchStartY=this.touchStartX=0;this.touchBoundary=c.touchBoundary||10;this.layer=a;this.tapDelay=c.tapDelay||200;if(!b.notNeeded(a)){for(var f="onMouse onClick onTouchStart onTouchMove onTouchEnd onTouchCancel".split(" "),e=0,g=f.length;e<g;e++)this[f[e]]=d(this[f[e]],this);h&&(a.addEventListener("mouseover",this.onMouse,!0),a.addEventListener("mousedown",this.onMouse,!0),
        a.addEventListener("mouseup",this.onMouse,!0));a.addEventListener("click",this.onClick,!0);a.addEventListener("touchstart",this.onTouchStart,!1);a.addEventListener("touchmove",this.onTouchMove,!1);a.addEventListener("touchend",this.onTouchEnd,!1);a.addEventListener("touchcancel",this.onTouchCancel,!1);Event.prototype.stopImmediatePropagation||(a.removeEventListener=function(c,d,b){var l=Node.prototype.removeEventListener;"click"===c?l.call(a,c,d.hijacked||d,b):l.call(a,c,d,b)},a.addEventListener=
        function(c,d,b){var l=Node.prototype.addEventListener;"click"===c?l.call(a,c,d.hijacked||(d.hijacked=function(a){a.propagationStopped||d(a)}),b):l.call(a,c,d,b)});"function"===typeof a.onclick&&(l=a.onclick,a.addEventListener("click",function(a){l(a)},!1),a.onclick=null)}}var h=0<navigator.userAgent.indexOf("Android"),e=/iP(ad|hone|od)/.test(navigator.userAgent),k=e&&/OS 4_\d(_\d)?/.test(navigator.userAgent),f=e&&/OS ([6-9]|\d{2})_\d/.test(navigator.userAgent),p=0<navigator.userAgent.indexOf("BB10");
        b.prototype.needsClick=function(a){switch(a.nodeName.toLowerCase()){case "button":case "select":case "textarea":if(a.disabled)return!0;break;case "input":if(e&&"file"===a.type||a.disabled)return!0;break;case "label":case "video":return!0}return/\bneedsclick\b/.test(a.className)};b.prototype.needsFocus=function(a){switch(a.nodeName.toLowerCase()){case "textarea":return!0;case "select":return!h;case "input":switch(a.type){case "button":case "checkbox":case "file":case "image":case "radio":case "submit":return!1}return!a.disabled&&
        !a.readOnly;default:return/\bneedsfocus\b/.test(a.className)}};b.prototype.sendClick=function(a,c){var d,b;document.activeElement&&document.activeElement!==a&&document.activeElement.blur();b=c.changedTouches[0];d=document.createEvent("MouseEvents");d.initMouseEvent(this.determineEventType(a),!0,!0,window,1,b.screenX,b.screenY,b.clientX,b.clientY,!1,!1,!1,!1,0,null);d.forwardedTouchEvent=!0;a.dispatchEvent(d)};b.prototype.determineEventType=function(a){return h&&"select"===a.tagName.toLowerCase()?
        "mousedown":"click"};b.prototype.focus=function(a){var c;e&&a.setSelectionRange&&0!==a.type.indexOf("date")&&"time"!==a.type?(c=a.value.length,a.setSelectionRange(c,c)):a.focus()};b.prototype.updateScrollParent=function(a){var c,d;c=a.fastClickScrollParent;if(!c||!c.contains(a)){d=a;do{if(d.scrollHeight>d.offsetHeight){c=d;a.fastClickScrollParent=d;break}d=d.parentElement}while(d)}c&&(c.fastClickLastScrollTop=c.scrollTop)};b.prototype.getTargetElementFromEventTarget=function(a){return a.nodeType===
        Node.TEXT_NODE?a.parentNode:a};b.prototype.onTouchStart=function(a){var c,d,b;if(1<a.targetTouches.length)return!0;c=this.getTargetElementFromEventTarget(a.target);d=a.targetTouches[0];if(e){b=window.getSelection();if(b.rangeCount&&!b.isCollapsed)return!0;if(!k){if(d.identifier&&d.identifier===this.lastTouchIdentifier)return a.preventDefault(),!1;this.lastTouchIdentifier=d.identifier;this.updateScrollParent(c)}}this.trackingClick=!0;this.trackingClickStart=a.timeStamp;this.targetElement=c;this.touchStartX=
        d.pageX;this.touchStartY=d.pageY;a.timeStamp-this.lastClickTime<this.tapDelay&&a.preventDefault();return!0};b.prototype.touchHasMoved=function(a){a=a.changedTouches[0];var c=this.touchBoundary;return Math.abs(a.pageX-this.touchStartX)>c||Math.abs(a.pageY-this.touchStartY)>c?!0:!1};b.prototype.onTouchMove=function(a){if(!this.trackingClick)return!0;if(this.targetElement!==this.getTargetElementFromEventTarget(a.target)||this.touchHasMoved(a))this.trackingClick=!1,this.targetElement=null;return!0};b.prototype.findControl=
        function(a){return void 0!==a.control?a.control:a.htmlFor?document.getElementById(a.htmlFor):a.querySelector("button, input:not([type=hidden]), keygen, meter, output, progress, select, textarea")};b.prototype.onTouchEnd=function(a){var c,d,b=this.targetElement;if(!this.trackingClick)return!0;if(a.timeStamp-this.lastClickTime<this.tapDelay)return this.cancelNextClick=!0;this.cancelNextClick=!1;this.lastClickTime=a.timeStamp;c=this.trackingClickStart;this.trackingClick=!1;this.trackingClickStart=0;
        f&&(d=a.changedTouches[0],b=document.elementFromPoint(d.pageX-window.pageXOffset,d.pageY-window.pageYOffset)||b,b.fastClickScrollParent=this.targetElement.fastClickScrollParent);d=b.tagName.toLowerCase();if("label"===d){if(c=this.findControl(b)){this.focus(b);if(h)return!1;b=c}}else if(this.needsFocus(b)){if(100<a.timeStamp-c||e&&window.top!==window&&"input"===d)return this.targetElement=null,!1;this.focus(b);this.sendClick(b,a);e&&"select"===d||(this.targetElement=null,a.preventDefault());return!1}if(e&&
        !k&&(c=b.fastClickScrollParent)&&c.fastClickLastScrollTop!==c.scrollTop)return!0;this.needsClick(b)||(a.preventDefault(),this.sendClick(b,a));return!1};b.prototype.onTouchCancel=function(){this.trackingClick=!1;this.targetElement=null};b.prototype.onMouse=function(a){return this.targetElement&&!a.forwardedTouchEvent&&a.cancelable?!this.needsClick(this.targetElement)||this.cancelNextClick?(a.stopImmediatePropagation?a.stopImmediatePropagation():a.propagationStopped=!0,a.stopPropagation(),a.preventDefault(),
        !1):!0:!0};b.prototype.onClick=function(a){if(this.trackingClick)return this.targetElement=null,this.trackingClick=!1,!0;if("submit"===a.target.type&&0===a.detail)return!0;a=this.onMouse(a);a||(this.targetElement=null);return a};b.prototype.destroy=function(){var a=this.layer;h&&(a.removeEventListener("mouseover",this.onMouse,!0),a.removeEventListener("mousedown",this.onMouse,!0),a.removeEventListener("mouseup",this.onMouse,!0));a.removeEventListener("click",this.onClick,!0);a.removeEventListener("touchstart",
        this.onTouchStart,!1);a.removeEventListener("touchmove",this.onTouchMove,!1);a.removeEventListener("touchend",this.onTouchEnd,!1);a.removeEventListener("touchcancel",this.onTouchCancel,!1)};b.notNeeded=function(a){var b,d;if("undefined"===typeof window.ontouchstart)return!0;if(d=+(/Chrome\/([0-9]+)/.exec(navigator.userAgent)||[,0])[1])if(h){if((b=document.querySelector("meta[name=viewport]"))&&(-1!==b.content.indexOf("user-scalable=no")||31<d&&document.documentElement.scrollWidth<=window.outerWidth))return!0}else return!0;
        return p&&(b=navigator.userAgent.match(/Version\/([0-9]*)\.([0-9]*)/),10<=b[1]&&3<=b[2]&&(b=document.querySelector("meta[name=viewport]"))&&(-1!==b.content.indexOf("user-scalable=no")||document.documentElement.scrollWidth<=window.outerWidth))?!0:"none"===a.style.msTouchAction?!0:!1};b.attach=function(a,c){return new b(a,c)};"function"==typeof define&&"object"==typeof define.amd&&define.amd?define(function(){return b}):"undefined"!==typeof g&&g.exports?(g.exports=b.attach,g.exports.FastClick=b):window.FastClick=
        b},{}],2:[function(n,g,m){window.Origami={fastclick:n("./bower_components/fastclick/lib/fastclick.js")}},{"./bower_components/fastclick/lib/fastclick.js":1}]},{},[2]);
        ;document.addEventListener('load',function(){document.dispatchEvent(new CustomEvent('o.load'))});document.addEventListener('DOMContentLoaded',function(){document.dispatchEvent(new CustomEvent('o.DOMContentLoaded'))});

        // apply fastclick to our document
        var attachFastClick = Origami.fastclick;
        attachFastClick(document.body);
      }
    }
  };

  // wait for cordova (and its plugins) to be ready
  document.addEventListener(
      "deviceready",
      function() {

        var adapter = new NativePageTransitionsKendoAdapter();
        adapter.loadFastClick();
        adapter.apply();

        // listen for elements with a-tags added to the dom
        var dispatchIndex = 0;
        document.body.addEventListener("DOMNodeInserted", function() {
          // TODO no event on wp8
          if (!event) {
            return;
          }
          var target = event.relatedNode;
          var addedAnchors = target.getElementsByTagName("a");
          if (addedAnchors.length > 0) {
            var thisIndex = ++dispatchIndex;
            setTimeout(function () {
              // enhance the anchors if there is no newer pending event within this timeout
              if (dispatchIndex == thisIndex) {
                window.NativePageTransitionsKendoAdapter.apply();
              }
            }, 20);
          }
        }, true);
      },
      false);
})();
