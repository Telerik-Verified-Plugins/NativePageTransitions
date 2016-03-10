#import "NativePageTransitions.h"

@implementation NativePageTransitions

#define IS_RETINA_DISPLAY() [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f
#define IS_RETINA_HD_DISPLAY() [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 3.0f
#define DISPLAY_SCALE IS_RETINA_HD_DISPLAY() ? 3.0f : (IS_RETINA_DISPLAY() ? 2.0f : 1.0f)

- (void) pluginInitialize {
    CGRect screenBound = [[UIScreen mainScreen] bounds];

    // Set our transitioning view (see #114)
  self.transitionView = self.webView;

    // Look to see if a WKWebView exists
    Class wkWebViewClass = NSClassFromString(@"WKWebView");
    if (wkWebViewClass) {
        for (int i = 0; i < self.webView.superview.subviews.count; i++) {
            UIView *subview = [self.webView.superview.subviews objectAtIndex:i];
            if ([subview isKindOfClass:wkWebViewClass]) {
                self.transitionView = self.wkWebView = (WKWebView *)subview;
            }
        }
    }

    // webview height may differ from screen height because of a statusbar
    _nonWebViewHeight = screenBound.size.width-self.transitionView.frame.size.width + screenBound.size.height-self.transitionView.frame.size.height;
}

- (void)dispose
{
  // Cleanup
  self.transitionView = nil;
  self.wkWebView = nil;

  [super dispose];
}

- (void) executePendingTransition:(CDVInvokedUrlCommand*)command {
  _command = command;
  if (_slideOptions != nil) {
    [self performSlideTransition];
  } else if (_flipOptions != nil) {
    [self performFlipTransition];
  } else if (_drawerOptions != nil) {
    [self performDrawerTransition];
  } else if (_fadeOptions != nil) {
    [self performFadeTransition];
  } else if (_curlOptions != nil) {
    [self performCurlTransition];
  }
}

- (void) cancelPendingTransition:(CDVInvokedUrlCommand*)command {
  _slideOptions = nil;
  _flipOptions = nil;
  _drawerOptions = nil;
  _fadeOptions = nil;
  _curlOptions = nil;

  // hide the screenshot like you mean it
  [_screenShotImageView removeFromSuperview];
  if (_originalColor != nil) {
    self.viewController.view.backgroundColor = _originalColor;
  }
  // doesn't matter if these weren't added, but if they were we need to remove them
  [_screenShotImageViewTop removeFromSuperview];
  [_screenShotImageViewBottom removeFromSuperview];

  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) slide:(CDVInvokedUrlCommand*)command {
  // make sure incorrect usage doesn't leave artifacts (call setup, then slide with delay >= 0)
  if (_slideOptions != nil) {
    [_screenShotImageView removeFromSuperview];
    [_screenShotImageViewTop removeFromSuperview];
    [_screenShotImageViewBottom removeFromSuperview];
  }

  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSString *href = [args objectForKey:@"href"];
  NSNumber *fixedPixelsTopNum = [args objectForKey:@"fixedPixelsTop"];
  NSNumber *fixedPixelsBottomNum = [args objectForKey:@"fixedPixelsBottom"];
  int fixedPixelsTop = [fixedPixelsTopNum intValue];
  int fixedPixelsBottom = [fixedPixelsBottomNum intValue];

  _originalColor = self.viewController.view.backgroundColor;
  self.viewController.view.backgroundColor = [UIColor blackColor];
  self.transitionView.layer.shadowOpacity = 0;

  //  CGFloat totalHeight = self.viewController.view.frame.size.height;
  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  CGRect screenshotRect = [self.viewController.view.window frame];

  // correct landscape detection on iOS < 8
  BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
  if (isLandscape && width < height) {
    screenshotRect = CGRectMake(screenshotRect.origin.x, screenshotRect.origin.y, screenshotRect.size.height, screenshotRect.size.width);
    CGFloat temp = width;
    width = height;
    height = temp;
  }


  UIImage *image =[self grabScreenshot];
  screenshotRect.size.height -= _webViewPushedDownPixels == 40 ? 20 : 0;
  _screenShotImageView = [[UIImageView alloc]initWithFrame:screenshotRect];
  [_screenShotImageView setImage:image];
  CGFloat retinaFactor = DISPLAY_SCALE;

  // in case of a statusbar above the webview, crop off the top
  if ((_nonWebViewHeight > 0 || fixedPixelsTop > 0) && [direction isEqualToString:@"down"]) {
        CGRect rect = CGRectMake(0.0f, (_nonWebViewHeight+fixedPixelsTop)*retinaFactor, image.size.width*retinaFactor, (image.size.height-_nonWebViewHeight-fixedPixelsTop)*retinaFactor);
        CGRect rect2 = CGRectMake(0.0f, _nonWebViewHeight+fixedPixelsTop, image.size.width, image.size.height-_nonWebViewHeight-fixedPixelsTop);
    CGImageRef tempImage = CGImageCreateWithImageInRect([image CGImage], rect);
    _screenShotImageView = [[UIImageView alloc]initWithFrame:rect2];
    [_screenShotImageView setImage:[UIImage imageWithCGImage:tempImage]];
    CGImageRelease(tempImage);
  }

  [self.transitionView.superview insertSubview:_screenShotImageView aboveSubview:self.transitionView];

  // Make a cropped version of the screenshot with only the top and/or bottom piece
  if (fixedPixelsTop > 0) {
        CGRect rect = CGRectMake(0.0f, _nonWebViewHeight*retinaFactor, image.size.width*retinaFactor, fixedPixelsTop*retinaFactor);
        CGRect rect2 = CGRectMake(0.0f, _nonWebViewHeight, image.size.width, fixedPixelsTop);
    CGImageRef tempImage = CGImageCreateWithImageInRect([image CGImage], rect);
    _screenShotImageViewTop = [[UIImageView alloc]initWithFrame:rect2];
    [_screenShotImageViewTop setImage:[UIImage imageWithCGImage:tempImage]];
    CGImageRelease(tempImage);
    [self.transitionView.superview insertSubview:_screenShotImageViewTop aboveSubview:([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"] ? self.transitionView : self.screenShotImageView)];
  }
  if (fixedPixelsBottom > 0) {
        CGRect rect = CGRectMake(0.0f, (image.size.height-fixedPixelsBottom)*retinaFactor, image.size.width*retinaFactor, fixedPixelsBottom*retinaFactor);
        CGRect rect2 = CGRectMake(0.0f, image.size.height-fixedPixelsBottom, image.size.width, fixedPixelsBottom);
    CGImageRef tempImage = CGImageCreateWithImageInRect([image CGImage], rect);
    _screenShotImageViewBottom = [[UIImageView alloc]initWithFrame:rect2];
    [_screenShotImageViewBottom setImage:[UIImage imageWithCGImage:tempImage]];
    CGImageRelease(tempImage);
    [self.transitionView.superview insertSubview:_screenShotImageViewBottom aboveSubview:([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"] ? self.transitionView : self.screenShotImageView)];
  }

  if ([self loadHrefIfPassed:href]) {
    // pass in -1 for manual (requires you to call executePendingTransition)
    NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
    _slideOptions = args;
    if (delay < 0) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
      [self performSlideTransition];
    }
  }
}

- (void) performSlideTransition {
  NSMutableDictionary *args = _slideOptions;
  _slideOptions = nil;
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  // duration/delay is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  CGFloat lowerLayerAlpha = 0.4f;
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue]; // pass in -1 for manual (requires you to call executePendingTransition)
  if (delay < 0) {
    delay = 0;
  }
  delay = delay / 1000;

    NSNumber *slidePixelsNum = [args objectForKey:@"slidePixels"];
    int slidePixels = [slidePixelsNum intValue];

  NSString *direction = [args objectForKey:@"direction"];
  NSNumber *slowdownfactor = [args objectForKey:@"slowdownfactor"];

  NSNumber *fixedPixelsTopNum = [args objectForKey:@"fixedPixelsTop"];
  int fixedPixelsTop = [fixedPixelsTopNum intValue];

  CGFloat transitionToX = 0;
  CGFloat transitionToY = 0;
  CGFloat webviewFromY = _nonWebViewHeight;
  CGFloat webviewToY = _nonWebViewHeight;
  int screenshotSlowdownFactor = 1;
  int webviewSlowdownFactor = 1;

  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;

  // correct landscape detection on iOS < 8
  BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
  if (isLandscape && width < height) {
    CGFloat temp = width;
    width = height;
    height = temp;
  }

  if ([direction isEqualToString:@"left"]) {
    transitionToX = -width;
    screenshotSlowdownFactor = [slowdownfactor intValue];
  } else if ([direction isEqualToString:@"right"]) {
    transitionToX = width;
    webviewSlowdownFactor = [slowdownfactor intValue];
  } else if ([direction isEqualToString:@"up"]) {
    screenshotSlowdownFactor = [slowdownfactor intValue];
    transitionToY = (-height/screenshotSlowdownFactor)+_nonWebViewHeight;
    webviewToY = _nonWebViewHeight;
    webviewFromY = height/webviewSlowdownFactor;
  } else if ([direction isEqualToString:@"down"]) {
    transitionToY = (height/screenshotSlowdownFactor)+_nonWebViewHeight;
    webviewSlowdownFactor = [slowdownfactor intValue];
    webviewFromY = (-height/webviewSlowdownFactor)+_nonWebViewHeight;
  }

    if (screenshotSlowdownFactor > 0) {
      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut
                       animations:^{
                          if ([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"]) {
                            // the screenshot was on top of the webview to hide any page changes, but now we need the webview on top again
                            [self.transitionView.superview sendSubviewToBack:_screenShotImageView];
                          }
                             if (slidePixels > 0) {
                                 [_screenShotImageView setAlpha:0];
                       }
                             [_screenShotImageView setFrame:CGRectMake(transitionToX/screenshotSlowdownFactor, slidePixels > 0 ? fixedPixelsTop+slidePixels : transitionToY, width, height)];
                         }
                       completion:^(BOOL finished) {
                         [_screenShotImageView removeFromSuperview];
                         if (_originalColor != nil) {
                           self.viewController.view.backgroundColor = _originalColor;
                         }
                         CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                         [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                       }];
    } else {
      [self.transitionView.superview sendSubviewToBack:_screenShotImageView];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (delay+duration) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
          [_screenShotImageView removeFromSuperview];
          if (_originalColor != nil) {
              self.viewController.view.backgroundColor = _originalColor;
          }
          CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
          [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
      });
    }

  // also, fade out the screenshot a bit to give it some depth
  if ([slowdownfactor intValue] != 1 && ([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"])) {
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                             _screenShotImageView.alpha = slidePixels > 0 ? 1.0f : lowerLayerAlpha;
                     }
                     completion:^(BOOL finished) {
                     }];
  }

    // without this on wkwebview the transition permanently cuts off the fixedPixelsTop
    if (self.wkWebView != nil) {
      fixedPixelsTop = 0;
    }

    if (webviewSlowdownFactor > 0) {
        if (fixedPixelsTop > 0) {
            [self.transitionView setBounds:CGRectMake(0, fixedPixelsTop, width, height-_nonWebViewHeight+fixedPixelsTop)];
            [self.transitionView setClipsToBounds:YES];
        }
        int corr = 0;
        if ([direction isEqualToString:@"left"] || [direction isEqualToString:@"right"]) {
      //corr = fixedPixelsTop;
        }
        if (slidePixels > 0) {
            [self.transitionView setAlpha:0];
            [self.transitionView.superview bringSubviewToFront:self.transitionView];
        }
        [self.transitionView setFrame:CGRectMake(-transitionToX/webviewSlowdownFactor, slidePixels > 0 ? fixedPixelsTop+slidePixels : webviewFromY+corr, width, height-_nonWebViewHeight)];

      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut
                       animations:^{
                       [self.transitionView setFrame:CGRectMake(0, webviewToY, width, height-_nonWebViewHeight)];
                             if (slidePixels > 0) {
                                 [self.transitionView setAlpha:1.0f];
                         }
                         }
                         completion:^(BOOL finished) {
                       }];
    }

    // let's make sure these are removed (#110 indicated they won't always disappear after animation finished)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (delay+duration) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // doesn't matter if these weren't added
        [_screenShotImageViewTop removeFromSuperview];
        [_screenShotImageViewBottom removeFromSuperview];
    });

    if (slidePixels <= 0 && [slowdownfactor intValue] != 1 && ([direction isEqualToString:@"right"] || [direction isEqualToString:@"down"])) {
    self.transitionView.alpha = lowerLayerAlpha;
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                             self.transitionView.alpha = 1.0f;
                     }
                     completion:^(BOOL finished) {
                     }];
  }
}

- (void) flip:(CDVInvokedUrlCommand*)command {
  _command = command;

  UIImage *image =[self grabScreenshot];
  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];

  _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
  [_screenShotImageView setImage:image];
  [self.transitionView.superview insertSubview:_screenShotImageView aboveSubview:self.transitionView];

  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  if ([self loadHrefIfPassed:[args objectForKey:@"href"]]) {
    // pass in -1 for manual (requires you to call executePendingTransition)
    NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
    _flipOptions = args;
    if (delay < 0) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    } else {
      [self performFlipTransition];
    }
  }
}

// Assumes input like "#00FF00" (#RRGGBB)
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0f];
}

- (void) performFlipTransition {
  NSMutableDictionary *args = _flipOptions;
  _flipOptions = nil;
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSString *direction = [args objectForKey:@"direction"];
  NSString *backgroundColor = [args objectForKey:@"backgroundColor"];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  if (delay < 0) {
    delay = 0;
  }

  // change the background color of the view if the user likes that (no need to change it back btw)
  if (backgroundColor != nil) {
    UIColor *theColor = [self colorFromHexString:backgroundColor];
    self.transitionView.superview.superview.backgroundColor = theColor;
  }

  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;

  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;

  UIViewAnimationOptions animationOptions;
  if ([direction isEqualToString:@"right"]) {
    if (width < height && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
      animationOptions = UIViewAnimationOptionTransitionFlipFromTop;
    } else {
      animationOptions = UIViewAnimationOptionTransitionFlipFromLeft;
    }
  } else if ([direction isEqualToString:@"left"]) {
    if (width < height && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
      animationOptions = UIViewAnimationOptionTransitionFlipFromBottom;
    } else {
      animationOptions = UIViewAnimationOptionTransitionFlipFromRight;
    }
  } else if ([direction isEqualToString:@"up"]) {
    if (width < height && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
      animationOptions = UIViewAnimationOptionTransitionFlipFromRight;
    } else {
      animationOptions = UIViewAnimationOptionTransitionFlipFromTop;
    }
  } else if ([direction isEqualToString:@"down"]) {
    if (width < height && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
      animationOptions = UIViewAnimationOptionTransitionFlipFromLeft;
    } else {
      animationOptions = UIViewAnimationOptionTransitionFlipFromBottom;
    }
  } else {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"direction should be one of up|down|left|right"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
    return;
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
    // remove the screenshot halfway during the transition
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (duration/2) * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      [_screenShotImageView removeFromSuperview];
    });
    [UIView transitionWithView:self.viewController.view
                      duration:duration
                       options:animationOptions | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{}
                    completion:^(BOOL finished) {
                      if (backgroundColor != nil) {
                        self.transitionView.superview.superview.backgroundColor = [UIColor blackColor];
                      }
                      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                      [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                    }];
  });
}

- (void) drawer:(CDVInvokedUrlCommand*)command {
  _command = command;

  UIImage *image =[self grabScreenshot];

  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *action = [args objectForKey:@"action"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];

  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;

  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  CGRect screenshotRect = [self.viewController.view.window frame];

  // correct landscape detection on iOS < 8
  BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
  if (isLandscape && width < height) {
    screenshotRect = CGRectMake(screenshotRect.origin.x, screenshotRect.origin.y, screenshotRect.size.height, screenshotRect.size.width);
    CGFloat temp = width;
    width = height;
    height = temp;
  }

  [_screenShotImageView setFrame:screenshotRect];
  if ([action isEqualToString:@"open"]) {
    _screenShotImageView = [[UIImageView alloc]initWithFrame:screenshotRect];
    // add a cool shadow
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:_screenShotImageView.bounds];
    _screenShotImageView.layer.masksToBounds = NO;
    _screenShotImageView.layer.shadowColor = [UIColor blackColor].CGColor;
    _screenShotImageView.layer.shadowOffset = CGSizeMake(0.0f, 5.0f);
    _screenShotImageView.layer.shadowOpacity = 0.5f;
    _screenShotImageView.layer.shadowPath = shadowPath.CGPath;
  }
  [_screenShotImageView setImage:image];
  if ([action isEqualToString:@"open"]) {
    [self.transitionView.superview insertSubview:_screenShotImageView aboveSubview:self.transitionView];
  } else {
    // add a cool shadow here as well
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:self.transitionView.bounds];
    self.transitionView.layer.masksToBounds = NO;
    self.transitionView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.transitionView.layer.shadowOffset = CGSizeMake(0.0f, 5.0f);
    self.transitionView.layer.shadowOpacity = 0.5f;
    self.transitionView.layer.shadowPath = shadowPath.CGPath;
  }

  if ([self loadHrefIfPassed:[args objectForKey:@"href"]]) {
    // pass in -1 for manual (requires you to call executePendingTransition)
    NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
    _drawerOptions = args;
    if (delay < 0) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
      [self performDrawerTransition];
    }
  }
}

- (void) performDrawerTransition {
  NSMutableDictionary *args = _drawerOptions;
  _drawerOptions = nil;
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSString *action = [args objectForKey:@"action"];
  NSString *origin = [args objectForKey:@"origin"];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  if (delay < 0) {
    delay = 0;
  }
  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;

  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;

  // correct landscape detection on iOS < 8
  BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
  if (isLandscape && width < height) {
    CGFloat temp = width;
    width = height;
    height = temp;
  }

  CGFloat transitionToX = 0;
  CGFloat webviewTransitionFromX = 0;
  int screenshotPx = 44;

  if ([action isEqualToString:@"open"]) {
    if ([origin isEqualToString:@"right"]) {
      transitionToX = -width+screenshotPx;
    } else {
      transitionToX = width-screenshotPx;
    }
  } else if ([action isEqualToString:@"close"]) {
    if ([origin isEqualToString:@"right"]) {
      transitionToX = screenshotPx;
      webviewTransitionFromX = -width+screenshotPx;
    } else {
      transitionToX = -width+screenshotPx;
      webviewTransitionFromX = width-screenshotPx;
    }
  }

  if ([action isEqualToString:@"open"]) {
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                       [_screenShotImageView setFrame:CGRectMake(transitionToX, 0, width, height)];
                     }
                     completion:^(BOOL finished) {
                       if ([action isEqualToString:@"close"]) {
                         _screenShotImageView = nil;
                         // [_screenShotImageView removeFromSuperview];
                       }
                       CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                       [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                     }];
  }

  if ([action isEqualToString:@"close"]) {
    [self.transitionView setFrame:CGRectMake(webviewTransitionFromX, _nonWebViewHeight, width, height-_nonWebViewHeight)];

    // position the webview above the screenshot just after the animation kicks in so no flash of the webview occurs
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay+50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      [self.transitionView.superview bringSubviewToFront:self.transitionView];
    });

    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                       [self.transitionView setFrame:CGRectMake(0, _nonWebViewHeight, width, height-_nonWebViewHeight)];
                     }
                     completion:^(BOOL finished) {
                       [_screenShotImageView removeFromSuperview];
                       CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                       [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                     }];
  }
}

- (void) fade:(CDVInvokedUrlCommand*)command {
  _command = command;

  UIImage *image =[self grabScreenshot];

  NSMutableDictionary *args = [command.arguments objectAtIndex:0];

  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];

  _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
  [_screenShotImageView setImage:image];
  [self.transitionView.superview insertSubview:_screenShotImageView aboveSubview:self.transitionView];

  if ([self loadHrefIfPassed:[args objectForKey:@"href"]]) {
    // pass in -1 for manual (requires you to call executePendingTransition)
    NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
    _fadeOptions = args;
    if (delay < 0) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
      [self performFadeTransition];
    }
  }
}

- (void) performFadeTransition {
  NSMutableDictionary *args = _fadeOptions;
  _fadeOptions = nil;
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
    NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];

  if (delay < 0) {
    delay = 0;
  }
  // delay/duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;

  UIViewAnimationOptions animationOptions = UIViewAnimationOptionTransitionCrossDissolve;

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      // remove the screenshot halfway during the transition
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (duration/2) * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
          [_screenShotImageView removeFromSuperview];
      });
      [UIView transitionWithView:self.viewController.view
                        duration:duration
                         options:animationOptions | UIViewAnimationOptionAllowAnimatedContent
                      animations:^{}
                      completion:^(BOOL finished) {
                          CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                          [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                      }];
  });
}

- (void) curl:(CDVInvokedUrlCommand*)command {
  _command = command;

  UIImage *image =[self grabScreenshot];

  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];

  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;

  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];

  _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
  [_screenShotImageView setImage:image];
  [self.transitionView.superview insertSubview:_screenShotImageView aboveSubview:self.transitionView];

  if ([self loadHrefIfPassed:[args objectForKey:@"href"]]) {
    // pass in -1 for manual (requires you to call executePendingTransition)
    NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
    _curlOptions = args;
    if (delay < 0) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
      [self performCurlTransition];
    }
  }
}

- (void) performCurlTransition {
  NSMutableDictionary *args = _curlOptions;
  _curlOptions = nil;
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSString *direction = [args objectForKey:@"direction"];

  if (delay < 0) {
    delay = 0;
  }
  // delay/duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;

  UIViewAnimationOptions animationOptions;
  if ([direction isEqualToString:@"up"]) {
    animationOptions = UIViewAnimationOptionTransitionCurlUp;
  } else if ([direction isEqualToString:@"down"]) {
    animationOptions = UIViewAnimationOptionTransitionCurlDown;
  } else {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"direction should be one of up|down"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
    return;
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
    // remove the screenshot halfway during the transition
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (duration/2) * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
      [_screenShotImageView removeFromSuperview];
    });
    [UIView transitionWithView:self.viewController.view
                      duration:duration
                       options:animationOptions | UIViewAnimationOptionAllowAnimatedContent
                    animations:^{}
                    completion:^(BOOL finished) {
                      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                      [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                    }];
  });
}

- (UIImage*) grabScreenshot {
  UIGraphicsBeginImageContextWithOptions(self.viewController.view.bounds.size, YES, 0.0f);

  // Since drawViewHierarchyInRect is slower than renderInContext we should only use it to overcome the bug in WKWebView
  if (self.wkWebView != nil) {
    [self.viewController.view drawViewHierarchyInRect:self.viewController.view.bounds afterScreenUpdates:NO];
  } else {
    [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  }

  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (BOOL) loadHrefIfPassed:(NSString*) href {
  UIWebView *uiwebview = nil;
  if ([self.webView isKindOfClass:[UIWebView class]]) {
    uiwebview = ((UIWebView*)self.webView);
  }
  if (href != nil && ![href isEqual:[NSNull null]]) {
    if (![href hasPrefix:@"#"] && [href rangeOfString:@".html"].location != NSNotFound) {
      // strip any params when looking for the file on the filesystem
      NSString *bareFileName = href;
      NSString *urlParams = nil;

      if (![bareFileName hasSuffix:@".html"]) {
        NSRange range = [href rangeOfString:@".html"];
        bareFileName = [href substringToIndex:range.location+5];
        urlParams = [href substringFromIndex:range.location+5];
      }
      NSURL *url;
        NSURL *origUrl;
      if (self.wkWebView != nil) {
          origUrl = self.wkWebView.URL;
      } else {
          origUrl = uiwebview.request.URL;
      }
        if([origUrl.scheme isEqualToString:@"file"]) {
            NSString *currentUrl = origUrl.absoluteString;
            NSRange lastSlash = [currentUrl rangeOfString:@"/" options:NSBackwardsSearch];
            NSString *path = [currentUrl substringToIndex:lastSlash.location+1];
            url = [NSURL URLWithString:[path stringByAppendingString:bareFileName]];
        } else {
            NSString *filePath = bareFileName;
            NSString *replaceWith = [@"/" stringByAppendingString:bareFileName];
            filePath = [origUrl.absoluteString stringByReplacingOccurrencesOfString:origUrl.path withString:replaceWith];
            url = [NSURL URLWithString:filePath];
        }

      // re-attach the params when loading the url
      if (urlParams != nil) {
        NSString *absoluteURLString = [url absoluteString];
        NSString *absoluteURLWithParams = [absoluteURLString stringByAppendingString: urlParams];
        url = [NSURL URLWithString:absoluteURLWithParams];
      }

      NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];

      // Utilize WKWebView for request if it exists
      if (self.wkWebView != nil) {
        [self.wkWebView loadRequest: urlRequest];
      } else {
        [uiwebview loadRequest: urlRequest];
      }
    } else if (![href hasPrefix:@"#"]) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"href must be null, a .html file or a #navigationhash"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
      return NO;
    } else {
      // it's a hash, so load the url without any possible current hash
      NSString *url = nil;
      if (self.wkWebView != nil) {
        url = self.wkWebView.URL.absoluteString;
      } else {
        url = uiwebview.request.URL.absoluteString;
      }

      // remove the # if it's still there
      if ([url rangeOfString:@"#"].location != NSNotFound) {
        NSRange range = [url rangeOfString:@"#"];
        url = [url substringToIndex:range.location];
      }
      // attach the hash
      url = [url stringByAppendingString:href];
      // and load it
      NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];

      if (self.wkWebView != nil) {
        [self.wkWebView loadRequest: urlRequest];
      } else {
        [uiwebview loadRequest: urlRequest];
      }
    }
  }
  return YES;
}
@end
