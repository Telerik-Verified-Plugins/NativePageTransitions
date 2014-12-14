package com.telerik.plugins.nativepagetransitions;

import android.graphics.Bitmap;
import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.animation.*;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.widget.ImageView;
import com.telerik.plugins.nativepagetransitions.lib.AnimationFactory;
import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Timer;
import java.util.TimerTask;

public class NativePageTransitions extends CordovaPlugin {

  private ImageView imageView;
  private ImageView imageView2;
  private long duration;
  private long delay;
  private String drawerAction;
  private String drawerOrigin;
  private String direction;
  private int slowdownfactor;
  private CallbackContext _callbackContext;
  private String _action;
  // this plugin listens to page changes, so only kick in a transition when it was actually requested by the JS bridge
  private boolean calledFromJS;
  private FrameLayout layout;
  private static final boolean BEFORE_KITKAT = Build.VERSION.SDK_INT < 19;
  private final boolean requiresRedraw = BEFORE_KITKAT;
  private static final String HREF_PREFIX = "file:///android_asset/www/";
  // this plugin listens to page changes, so only kick in a transition when it was actually requested by the JS bridge
  private String lastCallbackID;

  class MyCordovaWebViewClient extends CordovaWebViewClient {
    public MyCordovaWebViewClient(CordovaInterface cordova, CordovaWebView view) {
      super(cordova, view);
    }

    @Override
    public void onPageFinished(WebView view, String url) {
      super.onPageFinished(view, url);
      if ("slide".equalsIgnoreCase(_action)) {
        doSlideTransition();
      } else if ("flip".equalsIgnoreCase(_action)) {
        doFlipTransition();
      } else if ("drawer".equalsIgnoreCase(_action)) {
        doDrawerTransition();
      }
    }
  }

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);
    // required when a href is passed to better control the transition timing
    // TODO may be replaced by a 'load' listener (but that doesnt work for hashnav)
    webView.setWebViewClient(new MyCordovaWebViewClient(cordova, webView));
    imageView = new ImageView(cordova.getActivity().getBaseContext());
    imageView2 = new ImageView(cordova.getActivity().getBaseContext());

    // Transitions are below par when this is switched off in the manifest, so enabling it here.
    // We may need to have developers suppress this via a param in the future.
    enableHardwareAcceleration();

    layout = new FrameLayout(cordova.getActivity());
//    layout = new ViewAnimator(cordova.getActivity());
    layout.setLayoutParams(webView.getLayoutParams());
    ViewGroup vg = (ViewGroup) webView.getParent();
    if (vg != null) {
      vg.addView(layout, webView.getLayoutParams());
      vg.removeView(webView);
    }
    layout.addView(webView);
    layout.addView(imageView);
    layout.addView(imageView2);
  }

  int drawerNonOverlappingSpace;

  @Override
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    _action = action;
    _callbackContext = callbackContext;

    final JSONObject json = args.getJSONObject(0);
    final String href = json.isNull("href") ? null : json.getString("href");

    // check whether or not the file exists
    if (href != null && !"null".equals(href)) {
      if (!href.startsWith("#") && href.contains(".html")) {
        String localFile = href;
        if (!href.endsWith(".html")) {
          localFile = href.substring(0, href.indexOf(".html") + 5);
        }
        try {
          webView.getContext().getAssets().open("www/" + localFile);
        } catch (IOException ignore) {
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "href .html file not found: " + href));
          return false;
        }
      } else if (!href.startsWith("#")) {
        callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "href must be null, a .html file or a #navigationhash: " + href));
        return false;
      }
    }

    calledFromJS = true;

    // TODO move effects to separate classes, and reuse a lot of code
    if ("slide".equalsIgnoreCase(action)) {

      duration = json.getLong("duration");
      direction = json.getString("direction");
      delay = json.getLong("androiddelay");
      slowdownfactor = json.getInt("slowdownfactor");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          if (Build.VERSION.SDK_INT >= 12) {
            bitmap.setHasAlpha(false);
          }
          webView.setDrawingCacheEnabled(false);
          imageView.setImageBitmap(bitmap);
          bringToFront(imageView);

          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(HREF_PREFIX + href, false);
            } else {
              // it's a #hash
              String url = webView.getUrl();
              // strip any existing hash
              if (url.contains("#")) {
                url = url.substring(0, url.indexOf("#"));
              }
              webView.loadUrlIntoView(url + href, false);
            }
          } else {
            doSlideTransition();
          }
        }
      });

    } else if ("drawer".equalsIgnoreCase(action)) {

      if (drawerNonOverlappingSpace == 0) {
        drawerNonOverlappingSpace = webView.getWidth()/8;
      }
      duration = json.getLong("duration");
      drawerAction = json.getString("action");
      drawerOrigin = json.getString("origin");
      delay = json.getLong("androiddelay");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
//          if ("close".equals(drawerAction)) {
//            bringToFront(webView);
//          }

          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap;
          if ("open".equals(drawerAction)) {
            bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          } else {
            bitmap = Bitmap.createBitmap(webView.getDrawingCache(), "left".equals(drawerOrigin) ? 0 : drawerNonOverlappingSpace, 0, webView.getWidth()- drawerNonOverlappingSpace, webView.getHeight());
            if ("left".equals(drawerOrigin)) {
              if (Build.VERSION.SDK_INT >= 11) {
                imageView2.setX(-drawerNonOverlappingSpace / 2);
              }
            } else {
              if (Build.VERSION.SDK_INT >= 11) {
                imageView2.setX(drawerNonOverlappingSpace / 2);
              }
            }
          }
          if (Build.VERSION.SDK_INT >= 12) {
            bitmap.setHasAlpha(false);
          }
          webView.setDrawingCacheEnabled(false);
          if ("open".equals(drawerAction)) {
            imageView.setImageBitmap(bitmap);
            bringToFront(imageView);
          } else {
            imageView2.setImageBitmap(bitmap);
            bringToFront(imageView2);
          }

          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(HREF_PREFIX + href, false);
            } else {
              // it's a #hash
              String url = webView.getUrl();
              // strip any existing hash
              if (url.contains("#")) {
                url = url.substring(0, url.indexOf("#"));
              }
              webView.loadUrlIntoView(url + href, false);
            }
          } else {
            doDrawerTransition();
          }
        }
      });

    } else if ("flip".equalsIgnoreCase(action)) {

      duration = json.getLong("duration");
      direction = json.getString("direction");
      delay = json.getLong("androiddelay");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          if (Build.VERSION.SDK_INT >= 12) {
            bitmap.setHasAlpha(false);
          }
          webView.setDrawingCacheEnabled(false);
          imageView.setImageBitmap(bitmap);

          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(HREF_PREFIX + href, false);
            } else {
              // it's a #hash
              String url = webView.getUrl();
              // strip any existing hash
              if (url.contains("#")) {
                url = url.substring(0, url.indexOf("#"));
              }
              webView.loadUrlIntoView(url + href, false);
            }
          } else {
            doFlipTransition();
          }
        }
      });
    }
    return true;
  }

  private void doFlipTransition() {
    if (!calledFromJS || this._callbackContext.getCallbackId().equals(lastCallbackID)) {
      return;
    }
    lastCallbackID = this._callbackContext.getCallbackId();

    new Timer().schedule(new TimerTask() {
      public void run() {
        // manipulations of the imageView need to be done by the same thread
        // as the one that created it - the uithread in this case
        cordova.getActivity().runOnUiThread(new Runnable() {
          @Override
          public void run() {

            AnimationFactory.FlipDirection flipDirection;
            if ("left".equals(direction)) {
              flipDirection = AnimationFactory.FlipDirection.RIGHT_LEFT;
            } else if ("up".equals(direction)) {
              flipDirection = AnimationFactory.FlipDirection.LEFT_RIGHT; // TODO impl UP_DOWN;
            } else if ("down".equals(direction)) {
              flipDirection = AnimationFactory.FlipDirection.RIGHT_LEFT; // TODO impl DOWN_UP;
            } else {
              flipDirection = AnimationFactory.FlipDirection.LEFT_RIGHT;
            }

            final Animation[] animations = AnimationFactory.flipAnimation(imageView, webView, flipDirection, duration, null);

            animations[0].setAnimationListener(new Animation.AnimationListener() {
              @Override
              public void onAnimationStart(Animation animation) {
              }

              @Override
              public void onAnimationEnd(Animation animation) {
                imageView.setImageBitmap(null);
                animation.reset();
                imageView.clearAnimation();
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });
            animations[1].setAnimationListener(new Animation.AnimationListener() {
              @Override
              public void onAnimationStart(Animation animation) {
              }

              @Override
              public void onAnimationEnd(Animation animation) {
                animation.reset();
                webView.clearAnimation();
                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });

            imageView.startAnimation(animations[0]);
            webView.startAnimation(animations[1]);

            calledFromJS = false;
          }
        });
      }
    }, delay);
  }

  private void doSlideTransition() {
    if (!calledFromJS || this._callbackContext.getCallbackId().equals(lastCallbackID)) {
      return;
    }
    lastCallbackID = this._callbackContext.getCallbackId();

    new Timer().schedule(new TimerTask() {
      public void run() {
        // manipulations of the imageView need to be done by the same thread
        // as the one that created it - the uithread in this case
        cordova.getActivity().runOnUiThread(new Runnable() {
          @Override
          public void run() {

            float transitionToX = 0;
            float transitionToY = 0;
            int translateAnimationY = TranslateAnimation.RELATIVE_TO_PARENT;
            int screenshotSlowdownFactor = 1;
            int webviewSlowdownFactor = 1;

            if ("left".equals(direction)) {
              bringToFront(webView);
              transitionToX = -1;
              screenshotSlowdownFactor = slowdownfactor;
            } else if ("right".equals(direction)) {
              bringToFront(imageView);
              transitionToX = 1;
              webviewSlowdownFactor = slowdownfactor;
            } else if ("up".equals(direction)) {
              bringToFront(webView);
              transitionToY = -webView.getHeight();
              translateAnimationY = TranslateAnimation.ABSOLUTE;
              screenshotSlowdownFactor = slowdownfactor;
            } else if ("down".equals(direction)) {
              bringToFront(imageView);
              transitionToY = webView.getHeight();
              translateAnimationY = TranslateAnimation.ABSOLUTE;
              webviewSlowdownFactor = slowdownfactor;
            }

            // imageview animation
            final AnimationSet imageViewAnimation = new AnimationSet(true);

            final Animation imageViewAnimation1 = new TranslateAnimation(
                TranslateAnimation.RELATIVE_TO_PARENT, 0f,
                TranslateAnimation.RELATIVE_TO_PARENT, transitionToX / screenshotSlowdownFactor,
                translateAnimationY, 0,
                translateAnimationY, transitionToY / screenshotSlowdownFactor);
            imageViewAnimation1.setDuration(duration);
            imageViewAnimation.addAnimation(imageViewAnimation1);

            if (slowdownfactor != 1 && ("left".equals(direction) || "up".equals(direction))) {
              final Animation imageViewAnimation2 = new AlphaAnimation(1, 0.4f);
              imageViewAnimation2.setDuration(duration);
              imageViewAnimation.addAnimation(imageViewAnimation2);
            }

            // webview animation
            final AnimationSet webViewAnimation = new AnimationSet(true);

            final Animation webViewAnimation1 = new TranslateAnimation(
                TranslateAnimation.RELATIVE_TO_PARENT, -transitionToX / webviewSlowdownFactor,
                TranslateAnimation.RELATIVE_TO_PARENT, 0,
                TranslateAnimation.ABSOLUTE, -transitionToY / webviewSlowdownFactor,
                TranslateAnimation.ABSOLUTE, 0);
            webViewAnimation1.setDuration(duration);
            webViewAnimation.addAnimation(webViewAnimation1);
//            webViewAnimation1.setInterpolator(new OvershootInterpolator());

            if (slowdownfactor != 1 && ("right".equals(direction) || "down".equals(direction))) {
              final Animation webViewAnimation2 = new AlphaAnimation(0.4f, 1f);
              webViewAnimation2.setDuration(duration);
              webViewAnimation.addAnimation(webViewAnimation2);
            }

            imageViewAnimation.setAnimationListener(new Animation.AnimationListener() {
              @Override
              public void onAnimationStart(Animation animation) {
              }

              @Override
              public void onAnimationEnd(Animation animation) {
                imageView.setImageBitmap(null);
                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });

            imageView.setAnimation(imageViewAnimation);
            webView.setAnimation(webViewAnimation);
            layout.startLayoutAnimation();

            if (BEFORE_KITKAT) {
              // This fixes an issue observed on a Samsung Galaxy S3 /w Android 4.3 where the img is shown,
              // but the transition doesn't kick in unless the screen is touched again.
              imageView.requestFocusFromTouch();
              webView.requestFocus();
            }

            calledFromJS = false;
          }
        });
      }
    }, delay);
  }

  private void doDrawerTransition() {
    if (!calledFromJS || this._callbackContext.getCallbackId().equals(lastCallbackID)) {
      return;
    }
    lastCallbackID = this._callbackContext.getCallbackId();

    new Timer().schedule(new TimerTask() {
      public void run() {
        // manipulations of the imageView need to be done by the same thread
        // as the one that created it - the uithread in this case
        cordova.getActivity().runOnUiThread(new Runnable() {
          @Override
          public void run() {

            float width = webView.getWidth();
            float transitionToX = 0;
            float transitionFromX = 0;

            if ("open".equals(drawerAction)) {
              if ("right".equals(drawerOrigin)) {
                transitionToX = width - drawerNonOverlappingSpace;
              } else {
                transitionToX = -width + drawerNonOverlappingSpace;
              }
            } else if ("close".equals(drawerAction)) {
              if ("right".equals(drawerOrigin)) {
                transitionFromX = -width + drawerNonOverlappingSpace;
              } else {
                transitionFromX = width - drawerNonOverlappingSpace;
              }
            }

            final Animation animation = new TranslateAnimation(
                TranslateAnimation.ABSOLUTE, transitionFromX,
                TranslateAnimation.ABSOLUTE, -transitionToX,
                TranslateAnimation.ABSOLUTE, 0,
                TranslateAnimation.ABSOLUTE, 0);

            animation.setDuration(duration);

            animation.setAnimationListener(new Animation.AnimationListener() {
              @Override
              public void onAnimationStart(Animation animation) {
              }

              @Override
              public void onAnimationEnd(Animation animation) {
                if ("close".equals(drawerAction)) {
                  imageView.setImageBitmap(null);
                  imageView2.setImageBitmap(null);
                }
                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });

            if ("open".equals(drawerAction)) {
              animation.setFillAfter(true); // persists the screenshot
              imageView.startAnimation(animation);
            } else {
              // prevent a flash by moving the webview to the front with a little delay
              new Timer().schedule(new TimerTask() {
                public void run() {
                  cordova.getActivity().runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                      bringToFront(webView);
                    }
                  });
                }
              }, 80);
              webView.setAnimation(animation);
              layout.startLayoutAnimation();
            }
            calledFromJS = false;
          }
        });
      }
    }, delay);
  }

  private void bringToFront(View view) {
    view.bringToFront();
    if (requiresRedraw) {
      view.requestLayout();
    }
  }

  private void enableHardwareAcceleration() {
    if (Build.VERSION.SDK_INT >= 11) {
      cordova.getActivity().getWindow().setFlags(
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
      imageView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
      if (BEFORE_KITKAT) {
        webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
      }
    }
  }
}