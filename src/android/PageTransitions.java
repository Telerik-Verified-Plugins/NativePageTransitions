package nl.xservices.plugins.pagetransitions;

import android.graphics.Bitmap;
import android.view.animation.Animation;
import android.view.animation.TranslateAnimation;
import android.widget.ImageView;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.util.Timer;
import java.util.TimerTask;

public class PageTransitions extends CordovaPlugin {

  @Override
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {

    if ("slide".equalsIgnoreCase(action)) {

      final JSONObject json = args.getJSONObject(0);
      final long duration = json.getLong("duration");
      final String direction = json.getString("direction");
      final String file = json.isNull("file") ? null : json.getString("file");

      // check whether or not the file exists.. could be more elegant btw
      if (file != null) {
        try {
          webView.getContext().getAssets().open("www/" + file);
        } catch (IOException ignore) {
          callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, "file not found: " + file));
          return false;
        }
      }

      super.cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          webView.setDrawingCacheEnabled(true);
          Bitmap bitmap = Bitmap.createBitmap(webView.getDrawingCache());
          webView.setDrawingCacheEnabled(false);

          final ImageView imageView = new ImageView(webView.getContext());
          imageView.setImageBitmap(bitmap);
          webView.addView(imageView);

          if (file != null) {
            webView.loadUrlIntoView("file:///android_asset/www/" + file, false);
          }

          // wrapping the transition into timer so we can set a delay;
          // the more processing needs to be done to load the next view,
          // the larger the delay needs to be to get a smooth transition
          final long delay = file == null ? 30 : 300;

          new Timer().schedule(new TimerTask() {
            public void run() {
              try {
                float transitionToX = 0;
                float transitionFromY = 0;
                float transitionToY = 0;

                if ("left".equals(direction)) {
                  transitionToX = -1;
                  transitionFromY = webView.getScrollY();
                  transitionToY = webView.getScrollY();
                } else if ("right".equals(direction)) {
                  transitionToX = 1;
                  transitionFromY = webView.getScrollY();
                  transitionToY = webView.getScrollY();
                } else if ("up".equals(direction)) {
                  transitionFromY = webView.getScrollY();
                  transitionToY = -webView.getHeight();
                } else if ("down".equals(direction)) {
                  transitionFromY = webView.getScrollY();
                  transitionToY = webView.getHeight();
                }

                final TranslateAnimation trans = new TranslateAnimation(
                    TranslateAnimation.RELATIVE_TO_PARENT, 0f,
                    TranslateAnimation.RELATIVE_TO_PARENT, transitionToX,
                    TranslateAnimation.ABSOLUTE, transitionFromY,
                    TranslateAnimation.ABSOLUTE, transitionToY);

                trans.setDuration(duration);

                trans.setAnimationListener(new Animation.AnimationListener() {
                  @Override
                  public void onAnimationStart(Animation animation) {
                  }

                  @Override
                  public void onAnimationEnd(Animation animation) {
                    webView.removeView(imageView);
                    callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
                  }

                  @Override
                  public void onAnimationRepeat(Animation animation) {
                  }
                });
                imageView.startAnimation(trans);


              } catch (Exception e) {
                e.printStackTrace();
              }
            }
          }, delay);
        }
      });

      /*
    } else if ("fade".equalsIgnoreCase(action)) {
      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          final TranslateAnimation trans = new TranslateAnimation(
              TranslateAnimation.RELATIVE_TO_PARENT, 0f,
              TranslateAnimation.RELATIVE_TO_PARENT, 1f,
              TranslateAnimation.RELATIVE_TO_PARENT, 0f,
              TranslateAnimation.RELATIVE_TO_PARENT, 0f);
          trans.setDuration(400);

          final TranslateAnimation trans2 = new TranslateAnimation(
              TranslateAnimation.RELATIVE_TO_PARENT, -1f,
              TranslateAnimation.RELATIVE_TO_PARENT, 0f,
              TranslateAnimation.RELATIVE_TO_PARENT, 0f,
              TranslateAnimation.RELATIVE_TO_PARENT, 0f);

          trans2.setDuration(400);

          try {
            AlphaAnimation animation1 = new AlphaAnimation(1f, 0.6f);
            animation1.setDuration(300);
            animation1.setStartOffset(0);

            animation1.setAnimationListener(new Animation.AnimationListener() {

              @Override
              public void onAnimationEnd(Animation arg0) {
                AlphaAnimation animation2 = new AlphaAnimation(0.6f, 1f);
                animation2.setDuration(300);
                animation2.setStartOffset(0);
                webView.startAnimation(animation2);
              }

              @Override
              public void onAnimationRepeat(Animation arg0) {
              }

              @Override
              public void onAnimationStart(Animation arg0) {
              }
            });

            webView.startAnimation(animation1);
          } catch (Exception e) {
            e.printStackTrace();
          }


          new Timer().schedule(new TimerTask() {
            public void run() {
              try {
                //              secondWebView.startAnimation(trans2);
              } catch (Exception e) {
                e.printStackTrace();
              }
            }
          }, 400);


        }
      });

      //         mWebView.loadUrl("file:///android_asset/" + filename);

    */
    }
    return true;
  }
}