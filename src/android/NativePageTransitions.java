package com.telerik.plugins.nativepagetransitions;

import android.graphics.Bitmap;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.Animation;
import android.view.animation.TranslateAnimation;
import android.webkit.WebView;
import android.widget.ImageView;
import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Timer;
import java.util.TimerTask;

public class NativePageTransitions extends CordovaPlugin {

  ImageView imageView;
  long duration;
  long androiddelay;
  String direction;
  int slowdownfactor;

  CallbackContext _callbackContext;

  boolean calledFromJS;

  class MyCordovaWebViewClient extends CordovaWebViewClient {
    public MyCordovaWebViewClient(CordovaInterface cordova, CordovaWebView view) {
      super(cordova, view);
    }

    @Override
    public void onPageFinished(WebView view, String url) {
      super.onPageFinished(view, url);
      doTransition();
    }
  }

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);
    webView.setWebViewClient(new MyCordovaWebViewClient(cordova, webView));
  }

  @Override
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {

    // TODO move effects to seperate files
    if ("slide".equalsIgnoreCase(action)) {

      final JSONObject json = args.getJSONObject(0);
      duration = json.getLong("duration");
      androiddelay = json.getLong("androiddelay");
      direction = json.getString("direction");
      slowdownfactor = json.getInt("slowdownfactor");
      final String href = json.isNull("href") ? null : json.getString("href");
      _callbackContext = callbackContext;
      calledFromJS = true;

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

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          webView.setDrawingCacheEnabled(false);

          imageView = new ImageView(webView.getContext());
          imageView.setImageBitmap(bitmap);
          cordova.getActivity().addContentView(imageView, webView.getLayoutParams());

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
            doTransition();
          }
        }
      });
    }
    return true;
  }

  private void doTransition() {
    if (!calledFromJS) {
      System.err.println("---------------not calledFromJS !!!");
      return;
    }

    new Timer().schedule(new TimerTask() {
      public void run() {
        try {

          // manipulations of the imageView need to be done by the same thread
          // as the one that created it - the uithread in this case
          cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {

              float transitionToX = 0;
              float transitionToY = 0;
              int translateAnimationY = TranslateAnimation.RELATIVE_TO_PARENT;

              if ("left".equals(direction)) {
                transitionToX = -1;
              } else if ("right".equals(direction)) {
                transitionToX = 1;
              } else if ("up".equals(direction)) {
                transitionToY = -webView.getHeight();
                translateAnimationY = TranslateAnimation.ABSOLUTE;
              } else if ("down".equals(direction)) {
                transitionToY = webView.getHeight();
                translateAnimationY = TranslateAnimation.ABSOLUTE;
              }

              final TranslateAnimation imageViewAnimation = new TranslateAnimation(
                  TranslateAnimation.RELATIVE_TO_PARENT, 0f,
                  TranslateAnimation.RELATIVE_TO_PARENT, transitionToX,
                  translateAnimationY, 0,
                  translateAnimationY, transitionToY);
              imageViewAnimation.setDuration(duration);

              final TranslateAnimation webViewAnimation = new TranslateAnimation(
                  TranslateAnimation.RELATIVE_TO_PARENT, -transitionToX / slowdownfactor,
                  TranslateAnimation.RELATIVE_TO_PARENT, 0,
                  TranslateAnimation.ABSOLUTE, -transitionToY / slowdownfactor,
                  TranslateAnimation.ABSOLUTE, 0);
              webViewAnimation.setDuration(duration);

              imageViewAnimation.setAnimationListener(new Animation.AnimationListener() {
                @Override
                public void onAnimationStart(Animation animation) {
                }

                @Override
                public void onAnimationEnd(Animation animation) {
                  ViewGroup parent = (ViewGroup) imageView.getParent();
                  if (parent == null) {
                    System.err.println("-------------- have to set an imageview to invisible");
                    imageView.setVisibility(View.GONE);
                  } else {
                    parent.removeView(imageView);
                  }
                  _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
                }

                @Override
                public void onAnimationRepeat(Animation animation) {
                }
              });

              imageView.startAnimation(imageViewAnimation);
              webView.startAnimation(webViewAnimation);
              calledFromJS = false;
            }
          });

        } catch (Exception e) {
          e.printStackTrace();
        }
      }
    }, androiddelay);
  }
}