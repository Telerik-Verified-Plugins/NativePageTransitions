package com.telerik.plugins.nativepagetransitions;

import android.graphics.Bitmap;
import android.os.Build;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.TranslateAnimation;
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
  private long duration;
  private long androiddelay;
  private String direction;
  private int slowdownfactor;
  private CallbackContext _callbackContext;
  private String _action;
  private boolean calledFromJS;
  private FrameLayout layout;
  private final boolean requiresRedraw = Build.VERSION.SDK_INT < 19; // Build.VERSION_CODES.KITKAT

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
  }

  /*
  private void executePendingTransition() {
    if (true) {
      // TODO
    } else {
      _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "no pending transition"));
    }
  }
  */

  @Override
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    _action = action;
    _callbackContext = callbackContext;
    final JSONObject json = args.getJSONObject(0);
    final String href = json.isNull("href") ? null : json.getString("href");

    if ("executePendingTransition".equalsIgnoreCase(action)) {
      return true;
    }

    // check whether or not the file exists
    if (href != null) {
      if (href.contains(".html")) {
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

    // TODO move effects to separate classes
    if ("slide".equalsIgnoreCase(action)) {

      duration = json.getLong("duration");
      androiddelay = json.getLong("androiddelay");
      direction = json.getString("direction");
      slowdownfactor = json.getInt("slowdownfactor");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          webView.setDrawingCacheEnabled(false);
          imageView.setImageBitmap(bitmap);
          bringToFront(imageView);

          if (href != null) {
            if (href.contains(".html")) {
              webView.loadUrlIntoView("file:///android_asset/www/" + href, false);
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

    } else if ("flip".equalsIgnoreCase(action)) {

      direction = json.getString("direction");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          webView.setDrawingCacheEnabled(false);
          imageView.setImageBitmap(bitmap);

          if (href != null) {
            if (href.contains(".html")) {
              webView.loadUrlIntoView("file:///android_asset/www/" + href, false);
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
    if (!calledFromJS) {
      return;
    }

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
              flipDirection = AnimationFactory.FlipDirection.RIGHT_LEFT; // TODO impl DOWN_UP;
            } else if ("down".equals(direction)) {
              flipDirection = AnimationFactory.FlipDirection.LEFT_RIGHT; // TODO impl UP_DOWN;
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
    }, androiddelay);
  }

  private void doSlideTransition() {
    if (!calledFromJS) {
      return;
    }

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

            // NOTE: we could also use methods like AnimationFactory.inFromLeftAnimation(1000, null);

            final Animation imageViewAnimation = new TranslateAnimation(
                TranslateAnimation.RELATIVE_TO_PARENT, 0f,
                TranslateAnimation.RELATIVE_TO_PARENT, transitionToX / screenshotSlowdownFactor,
                translateAnimationY, 0,
                translateAnimationY, transitionToY / screenshotSlowdownFactor);
            imageViewAnimation.setDuration(duration);
//            imageViewAnimation.setInterpolator(new DecelerateInterpolator());

            final Animation webViewAnimation = new TranslateAnimation(
                TranslateAnimation.RELATIVE_TO_PARENT, -transitionToX / webviewSlowdownFactor,
                TranslateAnimation.RELATIVE_TO_PARENT, 0,
                TranslateAnimation.ABSOLUTE, -transitionToY / webviewSlowdownFactor,
                TranslateAnimation.ABSOLUTE, 0);
            webViewAnimation.setDuration(duration);
//            webViewAnimation.setInterpolator(new OvershootInterpolator());

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

//            imageView.animate()
//                .alpha(.7f)
//                .setDuration(2000)
//            .translationX(-600f)
//            .rotationX(20f)
//
//            ;
//            imageView.setVisibility(View.GONE);

//            webView.animate()
//                .alpha(.4f)
//                .setDuration(4000);
            imageView.setAnimation(imageViewAnimation);
            webView.setAnimation(webViewAnimation);
            layout.startLayoutAnimation();
//            layout.setAnimationCacheEnabled(true); //?

            calledFromJS = false;
          }
        });
      }
    }, androiddelay);
  }

  private void bringToFront(View view) {
    view.bringToFront();
    if (requiresRedraw) {
      view.requestLayout();
    }
  }
}