package com.telerik.plugins.nativepagetransitions;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.os.Build;
import android.util.DisplayMetrics;
import android.view.Gravity;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.animation.AlphaAnimation;
import android.view.animation.Animation;
import android.view.animation.AnimationSet;
import android.view.animation.TranslateAnimation;
import android.widget.FrameLayout;
import android.widget.ImageView;
import com.telerik.plugins.nativepagetransitions.lib.AnimationFactory;
import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Timer;
import java.util.TimerTask;

public class NativePageTransitions extends CordovaPlugin {

  private static final String ACTION_EXECUTE_PENDING_TRANSITION = "executePendingTransition";
  private static final String ACTION_CANCEL_PENDING_TRANSITION = "cancelPendingTransition";

  private static final String ACTION_SLIDE = "slide";
  private static final String ACTION_FADE = "fade";
  private static final String ACTION_FLIP = "flip";
  private static final String ACTION_DRAWER = "drawer";

  private ImageView imageView;
  private ImageView imageView2;
  private ImageView fixedImageViewTop;
  private ImageView fixedImageViewBottom;
  private float retinaFactor;
  private long duration;
  private long delay;
  private String drawerAction;
  private String drawerOrigin;
  private String direction;
  private String backgroundColor;
  private int slowdownfactor;
  private int slidePixels;
  private int fixedPixelsTop;
  private int fixedPixelsBottom;
  private CallbackContext _callbackContext;
  private String _action;
  // this plugin listens to page changes, so only kick in a transition when it was actually requested by the JS bridge
  // TODO remove this bool as we no longer rely on it due to xwalk and delay=-1 complexities
  private boolean calledFromJS;
  private FrameLayout layout;
  private static final boolean BEFORE_KITKAT = Build.VERSION.SDK_INT < 19;
  private final boolean requiresRedraw = BEFORE_KITKAT;
  // this plugin listens to page changes, so only kick in a transition when it was actually requested by the JS bridge
  private String lastCallbackID;
  private static boolean isCrosswalk;

  static {
    try {
      Class.forName("org.crosswalk.engine.XWalkWebViewEngine");
      isCrosswalk = true;
    } catch (Exception ignore) {
    }
  }

  // Helper to be compile-time compatible with both Cordova 3.x and 4.x.
  private View cachedView;
  private View getView() {
    if (cachedView == null) {
      try {
        cachedView = (View) webView.getClass().getMethod("getView").invoke(webView);
      } catch (Exception e) {
        cachedView = (View) webView;
      }
    }
    return cachedView;
  }

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);
    imageView = new ImageView(cordova.getActivity().getBaseContext());
    imageView2 = new ImageView(cordova.getActivity().getBaseContext());

    // Transitions are below par when this is switched off in the manifest, so enabling it here.
    // We may need to have developers suppress this via a param in the future.
    enableHardwareAcceleration();

    layout = new FrameLayout(cordova.getActivity());
    layout.setLayoutParams(getView().getLayoutParams());
    ViewGroup vg = (ViewGroup) getView().getParent();
    if (vg != null) {
      vg.addView(layout, getView().getLayoutParams());
      vg.removeView(getView());
    }
    layout.addView(getView());
    layout.addView(imageView);
    layout.addView(imageView2);

    DisplayMetrics metrics = new DisplayMetrics();
    cordova.getActivity().getWindowManager().getDefaultDisplay().getMetrics(metrics);
    retinaFactor = metrics.density;
  }

  int drawerNonOverlappingSpace;

  @Override
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    _callbackContext = callbackContext;

    if (ACTION_EXECUTE_PENDING_TRANSITION.equalsIgnoreCase(action)) {
      delay = 0;
      if (ACTION_SLIDE.equalsIgnoreCase(_action)) {
        doSlideTransition();
      } else if (ACTION_FADE.equalsIgnoreCase(_action)) {
        doFadeTransition();
      } else if (ACTION_FLIP.equalsIgnoreCase(_action)) {
        doFlipTransition();
      } else if (ACTION_DRAWER.equalsIgnoreCase(_action)) {
        doDrawerTransition();
      }
      return true;
    } else if (ACTION_CANCEL_PENDING_TRANSITION.equalsIgnoreCase(action)) {
      lastCallbackID = null;
      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          if (fixedImageViewTop != null) {
            fixedImageViewTop.setImageBitmap(null);
          }
          if (fixedImageViewBottom != null) {
            fixedImageViewBottom.setImageBitmap(null);
          }
          imageView.setImageBitmap(null);
          _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
        }
      });
      return true;
    }

    _action = action;

    final JSONObject json = args.getJSONObject(0);
    final String href = json.isNull("href") ? null : json.getString("href");

    calledFromJS = true;

    // TODO move effects to separate classes, and reuse lots of code
    if (ACTION_SLIDE.equalsIgnoreCase(action)) {
      duration = json.getLong("duration");
      direction = json.getString("direction");
      delay = json.getLong("androiddelay");
      slowdownfactor = json.getInt("slowdownfactor");
      slidePixels = json.optInt("slidePixels");
      fixedPixelsTop = json.getInt("fixedPixelsTop");
      fixedPixelsBottom = json.getInt("fixedPixelsBottom");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          Bitmap bitmap = getBitmap();
          imageView.setImageBitmap(bitmap);
          bringToFront(imageView);

          if (bitmap != null) {
            // crop the screenshot if fixed pixels have been passed when sliding left or right
            if (fixedPixelsTop > 0) {
              int cropHeight = (int)(fixedPixelsTop * retinaFactor);
              fixedImageViewTop = new ImageView(cordova.getActivity().getBaseContext());
              fixedImageViewTop.setImageBitmap(Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), cropHeight));
              final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP);
              layout.addView(fixedImageViewTop, lp);
              if ("down".equals(direction)) {
                // in case we slide down, strip off the fixedPixelsTop from the top of the screenshot
                bitmap = Bitmap.createBitmap(bitmap, 0, cropHeight, bitmap.getWidth(), bitmap.getHeight()-cropHeight);
                imageView.setScaleType(ImageView.ScaleType.FIT_END); // affects the entire plugin but is only relevant here
                imageView.setImageBitmap(bitmap);
              } else if ("up".equals(direction)) {
                // TODO in case we slide up, strip off the fixedPixelsTop from the top of the webview
                // TODO .. but this seems it a bit impossible.. (see my email of jan 24 2016)
              }
            }
            if (fixedPixelsBottom > 0) {
              int cropHeight = (int)(fixedPixelsBottom * retinaFactor);
              fixedImageViewBottom = new ImageView(cordova.getActivity().getBaseContext());
              fixedImageViewBottom.setImageBitmap(Bitmap.createBitmap(bitmap, 0, bitmap.getHeight()-cropHeight, bitmap.getWidth(), cropHeight));
              final FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM);
              layout.addView(fixedImageViewBottom, lp);
            }
          }

          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(webView.getUrl().substring(0, webView.getUrl().lastIndexOf('/')+1) + href, false);
            }
          }

          if (delay > -1) {
            doSlideTransition();
          } else {
            _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
          }
        }
      });

    } else if (ACTION_DRAWER.equalsIgnoreCase(action)) {

      if (drawerNonOverlappingSpace == 0) {
        drawerNonOverlappingSpace = getView().getWidth()/8;
      }
      duration = json.getLong("duration");
      drawerAction = json.getString("action");
      drawerOrigin = json.getString("origin");
      delay = json.getLong("androiddelay");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          Bitmap bitmap;
          if ("open".equals(drawerAction)) {
            bitmap = getBitmap();
          } else {
            // TODO Crosswalk compat
            getView().setDrawingCacheEnabled(true);
            bitmap = Bitmap.createBitmap(getView().getDrawingCache(), "left".equals(drawerOrigin) ? 0 : drawerNonOverlappingSpace, 0, getView().getWidth()- drawerNonOverlappingSpace, getView().getHeight());
            if ("left".equals(drawerOrigin)) {
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
                imageView2.setX(-drawerNonOverlappingSpace / 2);
              }
            } else {
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
                imageView2.setX(drawerNonOverlappingSpace / 2);
              }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB_MR1) {
              bitmap.setHasAlpha(false);
            }
            getView().setDrawingCacheEnabled(false);
          }
          if ("open".equals(drawerAction)) {
            imageView.setImageBitmap(bitmap);
            bringToFront(imageView);
          } else {
            imageView2.setImageBitmap(bitmap);
            bringToFront(imageView2);
          }

          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(webView.getUrl().substring(0, webView.getUrl().lastIndexOf('/')+1) + href, false);
            }
          }

          if (delay > -1) {
            doDrawerTransition();
          } else {
            _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
          }
        }
      });

    } else if (ACTION_FADE.equalsIgnoreCase(action)) {

      duration = json.getLong("duration");
      delay = json.getLong("androiddelay");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          imageView.setImageBitmap(getBitmap());
          bringToFront(imageView);

          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(webView.getUrl().substring(0, webView.getUrl().lastIndexOf('/')+1) + href, false);
            }
          }

          if (delay > -1) {
            doFadeTransition();
          } else {
            _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
          }
        }
      });

    } else if (ACTION_FLIP.equalsIgnoreCase(action)) {

      duration = json.getLong("duration");
      direction = json.getString("direction");
      delay = json.getLong("androiddelay");
      backgroundColor = json.optString("backgroundColor");

      cordova.getActivity().runOnUiThread(new Runnable() {
        @Override
        public void run() {
          if (backgroundColor != null && backgroundColor.startsWith("#")) {
            ((View)getView().getParent()).setBackgroundColor(Color.parseColor(backgroundColor));
          }
          imageView.setImageBitmap(getBitmap());
          bringToFront(imageView);
          if (href != null && !"null".equals(href)) {
            if (!href.startsWith("#") && href.contains(".html")) {
              webView.loadUrlIntoView(webView.getUrl().substring(0, webView.getUrl().lastIndexOf('/')+1) + href, false);
            }
          }

          if (delay > -1) {
            doFlipTransition();
          } else {
            _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
          }
        }
      });
    }
    return true;
  }

  private void doFadeTransition() {
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

            final Animation[] animations = new Animation[] {
                AnimationFactory.fadeOutAnimation(duration, imageView),
                AnimationFactory.fadeInAnimation(duration, getView())
            };

            animations[0].setAnimationListener(new Animation.AnimationListener() {
              @Override
              public void onAnimationStart(Animation animation) {
              }

              @Override
              public void onAnimationEnd(Animation animation) {
                bringToFront(getView());
//                animation.reset();
                getView().clearAnimation();
                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
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
                imageView.setImageBitmap(null);
//                animation.reset();
                imageView.clearAnimation();
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });

            imageView.startAnimation(animations[0]);
            getView().startAnimation(animations[1]);

            calledFromJS = false;
          }
        });
      }
    }, delay);
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

            final Animation[] animations = AnimationFactory.flipAnimation(imageView, getView(), flipDirection, duration, null);

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
                getView().clearAnimation();
                if (backgroundColor != null && backgroundColor.startsWith("#")) {
                  backgroundColor = null;
                  ((View)getView().getParent()).setBackgroundColor(Color.BLACK);
                }
                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });

            imageView.startAnimation(animations[0]);
            getView().startAnimation(animations[1]);

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
              bringToFront(getView());
              transitionToX = -1;
              screenshotSlowdownFactor = slowdownfactor;
            } else if ("right".equals(direction)) {
              bringToFront(imageView);
              transitionToX = 1;
              webviewSlowdownFactor = slowdownfactor;
            } else if ("up".equals(direction)) {
              bringToFront(getView());
              transitionToY = -getView().getHeight();
              translateAnimationY = TranslateAnimation.ABSOLUTE;
              screenshotSlowdownFactor = slowdownfactor;
            } else if ("down".equals(direction)) {
              bringToFront(imageView);
              transitionToY = getView().getHeight();
              translateAnimationY = TranslateAnimation.ABSOLUTE;
              webviewSlowdownFactor = slowdownfactor;
            }

            if (fixedImageViewTop != null) {
              bringToFront(fixedImageViewTop);
            }
            if (fixedImageViewBottom != null) {
              bringToFront(fixedImageViewBottom);
            }

            // imageview animation
            final AnimationSet imageViewAnimation = new AnimationSet(true);

            if (screenshotSlowdownFactor > 0) {
              final Animation imageViewAnimation1 = new TranslateAnimation(
                  TranslateAnimation.RELATIVE_TO_PARENT, 0f,
                  TranslateAnimation.RELATIVE_TO_PARENT, transitionToX / screenshotSlowdownFactor,
                  translateAnimationY, 0,
                  translateAnimationY, slidePixels > 0 ? slidePixels : (transitionToY / screenshotSlowdownFactor));
              imageViewAnimation1.setDuration(duration);
              imageViewAnimation.addAnimation(imageViewAnimation1);
            }

            if (slowdownfactor != 1 && ("left".equals(direction) || "up".equals(direction))) {
              if (slidePixels <= 0) {
                final Animation imageViewAnimation2 = new AlphaAnimation(1, 0.4f);
                imageViewAnimation2.setDuration(duration);
                imageViewAnimation.addAnimation(imageViewAnimation2);
              }
            }

            // webview animation
            final AnimationSet webViewAnimationSet = new AnimationSet(true);

            if (webviewSlowdownFactor > 0) {
              final Animation webViewAnimation1 = new TranslateAnimation(
                  TranslateAnimation.RELATIVE_TO_PARENT, -transitionToX / webviewSlowdownFactor,
                  TranslateAnimation.RELATIVE_TO_PARENT, 0,
                  TranslateAnimation.ABSOLUTE, slidePixels > 0 ? slidePixels : (-transitionToY / webviewSlowdownFactor),
                  TranslateAnimation.ABSOLUTE, 0);
              webViewAnimation1.setDuration(duration);
              webViewAnimationSet.addAnimation(webViewAnimation1);
              //webViewAnimation1.setInterpolator(new OvershootInterpolator());
            }

            if (slidePixels <= 0 &&
                slowdownfactor != 1 &&
                ("right".equals(direction) || "down".equals(direction))) {
              final Animation webViewAnimation2 = new AlphaAnimation(0.4f, 1f);
              webViewAnimation2.setDuration(duration);
              webViewAnimationSet.addAnimation(webViewAnimation2);
            }

            if (slidePixels > 0) {
              if ("up".equals(direction)) {
                webViewAnimationSet.addAnimation(AnimationFactory.fadeInAnimation(duration, getView()));
              } else if ("down".equals(direction)) {
                imageViewAnimation.addAnimation(AnimationFactory.fadeOutAnimation(duration, imageView));
              }
            }

            webViewAnimationSet.setAnimationListener(new Animation.AnimationListener() {
              @Override
              public void onAnimationStart(Animation animation) {
              }

              @Override
              public void onAnimationEnd(Animation animation) {
                // prevent a flash by removing the optional fixed header/footer screenshots after a little delay
                if (fixedImageViewTop != null || fixedImageViewBottom != null) {
                  new Timer().schedule(new TimerTask() {
                    public void run() {
                      cordova.getActivity().runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                          if (fixedImageViewTop != null) {
                            fixedImageViewTop.setImageBitmap(null);
                          }
                          if (fixedImageViewBottom != null) {
                            fixedImageViewBottom.setImageBitmap(null);
                          }
                          imageView.setImageBitmap(null);
                        }
                      });
                    }
                  }, 20);
                }
                bringToFront(getView());
                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK));
              }

              @Override
              public void onAnimationRepeat(Animation animation) {
              }
            });

            imageView.setAnimation(imageViewAnimation);
            if (slidePixels <=0 || !"down".equals(direction)) {
              getView().setAnimation(webViewAnimationSet);
            }

            if (BEFORE_KITKAT) {
              //fixes a problem where the animation didn't start unless the user touched the screen once
              layout.invalidate();
            }

            layout.startLayoutAnimation();

            if (BEFORE_KITKAT) {
              // This fixes an issue observed on a Samsung Galaxy S3 /w Android 4.3 where the img is shown,
              // but the transition doesn't kick in unless the screen is touched again.
              // note that with 'layout.invalidate();' this may be obsolete but I can't reproduce the issue anyway
              imageView.requestFocusFromTouch();
              getView().requestFocus();
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

            float width = getView().getWidth();
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
              animation.setFillAfter(true); // persists the screenshot (not working on crosswalk btw..)
              imageView.startAnimation(animation);
            } else {
              // prevent a flash by moving the webview to the front with a little delay
              new Timer().schedule(new TimerTask() {
                public void run() {
                  cordova.getActivity().runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                      bringToFront(getView());
                    }
                  });
                }
              }, 80);
              getView().setAnimation(animation);
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
    view.setVisibility(View.VISIBLE);
    if (requiresRedraw) {
      view.requestLayout();
    }
  }

  private Bitmap getBitmap() {
    Bitmap bitmap = null;
    if (isCrosswalk) {
      try {
        TextureView textureView = findCrosswalkTextureView((ViewGroup) getView());
        bitmap = textureView.getBitmap();
      } catch(Exception ignore) {
      }
    } else {
      View view = getView();
      view.setDrawingCacheEnabled(true);
      bitmap = Bitmap.createBitmap(view.getDrawingCache());
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB_MR1) {
        bitmap.setHasAlpha(false);
      }
      view.setDrawingCacheEnabled(false);
    }
    return bitmap;
  }

  private TextureView findCrosswalkTextureView(ViewGroup group) {
    int childCount = group.getChildCount();
    for(int i=0;i<childCount;i++) {
      View child = group.getChildAt(i);
      if(child instanceof TextureView) {
        String parentClassName = child.getParent().getClass().toString();
        boolean isRightKindOfParent = (parentClassName.contains("XWalk"));
        if(isRightKindOfParent) {
          return (TextureView) child;
        }
      } else if(child instanceof ViewGroup) {
        TextureView textureView = findCrosswalkTextureView((ViewGroup) child);
        if(textureView != null) {
          return textureView;
        }
      }
    }
    return null;
  }

  private void enableHardwareAcceleration() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
      cordova.getActivity().getWindow().setFlags(
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
      imageView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
      if (BEFORE_KITKAT && !isCrosswalk) {
        getView().setLayerType(View.LAYER_TYPE_SOFTWARE, null);
      }
    }
  }
}