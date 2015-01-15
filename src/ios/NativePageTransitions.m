#import "NativePageTransitions.h"

@implementation NativePageTransitions

#define IS_RETINA_DISPLAY() [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f
#define IS_RETINA_HD_DISPLAY() [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 3.0f
#define DISPLAY_SCALE IS_RETINA_HD_DISPLAY() ? 3.0f : (IS_RETINA_DISPLAY() ? 2.0f : 1.0f)

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView {
  self = [super initWithWebView:theWebView];
  CGRect screenBound = [[UIScreen mainScreen] bounds];
  // webview height may differ from screen height because of a statusbar
  _nonWebViewHeight = screenBound.size.width-self.webView.frame.size.width + screenBound.size.height-self.webView.frame.size.height;
  return self;
}

- (void) slide:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSString *href = [args objectForKey:@"href"];
  NSNumber *slowdownfactor = [args objectForKey:@"slowdownfactor"];
  NSNumber *fixedPixelsTopNum = [args objectForKey:@"fixedPixelsTop"];
  NSNumber *fixedPixelsBottomNum = [args objectForKey:@"fixedPixelsBottom"];
  int fixedPixelsTop = [fixedPixelsTopNum intValue];
  int fixedPixelsBottom = [fixedPixelsBottomNum intValue];
  
  self.viewController.view.backgroundColor = [UIColor blackColor];
  self.webView.layer.shadowOpacity = 0;
  
  // duration/delay is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;
  CGFloat lowerLayerAlpha = 0.4f; // TODO consider passing in
  
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
  
  CGFloat transitionToX = 0;
  CGFloat transitionToY = 0;
  CGFloat webviewFromY = _nonWebViewHeight;
  CGFloat webviewToY = _nonWebViewHeight;
  int screenshotSlowdownFactor = 1;
  int webviewSlowdownFactor = 1;
  
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
  
  CGSize viewSize = self.viewController.view.bounds.size;
  
  UIGraphicsBeginImageContextWithOptions(viewSize, YES, 0.0);
  [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  _screenShotImageView = [[UIImageView alloc]initWithFrame:screenshotRect];
  [_screenShotImageView setImage:image];
  CGFloat retinaFactor = DISPLAY_SCALE;
  
  // in case of a statusbar above the webview, crop off the top
  if (_nonWebViewHeight > 0 && [direction isEqualToString:@"down"]) {
    CGRect rect = CGRectMake(0.0, _nonWebViewHeight*retinaFactor, image.size.width*retinaFactor, (image.size.height-_nonWebViewHeight)*retinaFactor);
    CGRect rect2 = CGRectMake(0.0, _nonWebViewHeight, image.size.width, image.size.height-_nonWebViewHeight);
    CGImageRef tempImage = CGImageCreateWithImageInRect([image CGImage], rect);
    _screenShotImageView = [[UIImageView alloc]initWithFrame:rect2];
    [_screenShotImageView setImage:[UIImage imageWithCGImage:tempImage]];
    CGImageRelease(tempImage);
  }
  
  if ([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"]) {
    [self.webView.superview insertSubview:_screenShotImageView belowSubview:self.webView];
  } else {
    [self.webView.superview insertSubview:_screenShotImageView aboveSubview:self.webView];
  }
  
  // Make a cropped version of the screenshot with only the top and/or bottom piece. Only for left/right slides atm.
  if ([direction isEqualToString:@"left"] || [direction isEqualToString:@"right"]) {
    if (fixedPixelsTop > 0) {
      CGRect rect = CGRectMake(0.0, _nonWebViewHeight*retinaFactor, image.size.width*retinaFactor, fixedPixelsTop*retinaFactor);
      CGRect rect2 = CGRectMake(0.0, _nonWebViewHeight, image.size.width, fixedPixelsTop);
      CGImageRef tempImage = CGImageCreateWithImageInRect([image CGImage], rect);
      _screenShotImageViewTop = [[UIImageView alloc]initWithFrame:rect2];
      [_screenShotImageViewTop setImage:[UIImage imageWithCGImage:tempImage]];
      CGImageRelease(tempImage);
      [self.webView.superview insertSubview:_screenShotImageViewTop aboveSubview:([direction isEqualToString:@"left"] ? self.webView : self.screenShotImageView)];
    }
    if (fixedPixelsBottom > 0) {
      CGRect rect = CGRectMake(0.0, (image.size.height-fixedPixelsBottom)*retinaFactor, image.size.width*retinaFactor, fixedPixelsBottom*retinaFactor);
      CGRect rect2 = CGRectMake(0.0, image.size.height-fixedPixelsBottom, image.size.width, fixedPixelsBottom);
      CGImageRef tempImage = CGImageCreateWithImageInRect([image CGImage], rect);
      _screenShotImageViewBottom = [[UIImageView alloc]initWithFrame:rect2];
      [_screenShotImageViewBottom setImage:[UIImage imageWithCGImage:tempImage]];
      CGImageRelease(tempImage);
      [self.webView.superview insertSubview:_screenShotImageViewBottom aboveSubview:([direction isEqualToString:@"left"] ? self.webView : self.screenShotImageView)];
    }
  }
  
  if ([self loadHrefIfPassed:href]) {
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut // TODO: allow passing in?
                     animations:^{
                       [_screenShotImageView setFrame:CGRectMake(transitionToX/screenshotSlowdownFactor, transitionToY, width, height)];
                     }
                     completion:^(BOOL finished) {
                       [_screenShotImageView removeFromSuperview];
                       CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                       [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                     }];
    
    // also, fade out the screenshot a bit to give it some depth
    if ([slowdownfactor intValue] != 1 && ([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"])) {
      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut
                       animations:^{
                         _screenShotImageView.alpha = lowerLayerAlpha;
                       }
                       completion:^(BOOL finished) {
                       }];
    }
    
    [self.webView setFrame:CGRectMake(-transitionToX/webviewSlowdownFactor, webviewFromY, width, height-_nonWebViewHeight)];
    
    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                       [self.webView setFrame:CGRectMake(0, webviewToY, width, height-_nonWebViewHeight)];
                     }
                     completion:^(BOOL finished) {
                       // doesn't matter if these weren't added
                       [_screenShotImageViewTop removeFromSuperview];
                       [_screenShotImageViewBottom removeFromSuperview];
                     }];
    
    if ([slowdownfactor intValue] != 1 && ([direction isEqualToString:@"right"] || [direction isEqualToString:@"down"])) {
      self.webView.alpha = lowerLayerAlpha;
      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut
                       animations:^{
                         self.webView.alpha = 1.0;
                       }
                       completion:^(BOOL finished) {
                       }];
    }
  }
}

- (void) drawer:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *action = [args objectForKey:@"action"];
  NSString *origin = [args objectForKey:@"origin"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSString *href = [args objectForKey:@"href"];
  
  // duration/delay is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;
  
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
  
  CGSize viewSize = self.viewController.view.bounds.size;
  UIGraphicsBeginImageContextWithOptions(viewSize, YES, 0.0);
  [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
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
    [self.webView.superview insertSubview:_screenShotImageView aboveSubview:self.webView];
  } else {
    // add a cool shadow here as well
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:self.webView.bounds];
    self.webView.layer.masksToBounds = NO;
    self.webView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.webView.layer.shadowOffset = CGSizeMake(0.0f, 5.0f);
    self.webView.layer.shadowOpacity = 0.5f;
    self.webView.layer.shadowPath = shadowPath.CGPath;
  }
  
  if ([self loadHrefIfPassed:href]) {
    if ([action isEqualToString:@"open"]) {
      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut // TODO: allow passing in?
                       animations:^{
                         [_screenShotImageView setFrame:CGRectMake(transitionToX, 0, width, height)];
                       }
                       completion:^(BOOL finished) {
                         if ([action isEqualToString:@"close"]) {
                           _screenShotImageView = nil;
                           // [_screenShotImageView removeFromSuperview];
                         }
                         CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
    }
    
    if ([action isEqualToString:@"close"]) {
      [self.webView setFrame:CGRectMake(webviewTransitionFromX, _nonWebViewHeight, width, height-_nonWebViewHeight)];
      
      // position the webview above the screenshot just after the animation kicks in so no flash of the webview occurs
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay+50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [self.webView.superview bringSubviewToFront:self.webView];
      });
      
      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut
                       animations:^{
                         [self.webView setFrame:CGRectMake(0, _nonWebViewHeight, width, height-_nonWebViewHeight)];
                       }
                       completion:^(BOOL finished) {
                         [_screenShotImageView removeFromSuperview];
                         CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
    }
  }
}

- (void) flip:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSString *href = [args objectForKey:@"href"];
  
  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  
  // overlay the webview with a screenshot to prevent the user from seeing changes in the webview before the flip kicks in
  CGSize viewSize = self.viewController.view.bounds.size;
  
  UIGraphicsBeginImageContextWithOptions(viewSize, YES, 0.0);
  [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];
  
  _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
  [_screenShotImageView setImage:image];
  [self.webView.superview insertSubview:_screenShotImageView aboveSubview:self.webView];
  
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
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    return;
  }
  
  if ([self loadHrefIfPassed:href]) {
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
                        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                      }];
    });
  }
}

- (void) curl:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSString *href = [args objectForKey:@"href"];
  
  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  
  // overlay the webview with a screenshot to prevent the user from seeing changes in the webview before the flip kicks in
  CGSize viewSize = self.viewController.view.bounds.size;
  
  UIGraphicsBeginImageContextWithOptions(viewSize, YES, 0.0);
  [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];
  
  _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
  [_screenShotImageView setImage:image];
  [self.webView.superview insertSubview:_screenShotImageView aboveSubview:self.webView];
  
  UIViewAnimationOptions animationOptions;
  if ([direction isEqualToString:@"up"]) {
    animationOptions = UIViewAnimationOptionTransitionCurlUp;
  } else if ([direction isEqualToString:@"down"]) {
    animationOptions = UIViewAnimationOptionTransitionCurlDown;
  } else {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"direction should be one of up|down"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    return;
  }
  
  if ([self loadHrefIfPassed:href]) {
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
                        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                      }];
    });
  }
}

- (BOOL) loadHrefIfPassed:(NSString*) href {
  if (href != nil && href != [NSNull null]) {
    if (![href hasPrefix:@"#"] && [href rangeOfString:@".html"].location != NSNotFound) {
      // strip any params when looking for the file on the filesystem
      NSString *bareFileName = href;
      NSString *urlParams = nil;
      
      if (![bareFileName hasSuffix:@".html"]) {
        NSRange range = [href rangeOfString:@".html"];
        bareFileName = [href substringToIndex:range.location+5];
        urlParams = [href substringFromIndex:range.location+5];
      }
      NSString *filePath = [self.commandDelegate pathForResource:bareFileName];
      if (filePath == nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"file not found"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
        return NO;
      }
      
      NSURL *url = [NSURL fileURLWithPath: filePath];
      // re-attach the params when loading the url
      if (urlParams != nil) {
        NSString *absoluteURLString = [url absoluteString];
        NSString *absoluteURLWithParams = [absoluteURLString stringByAppendingString: urlParams];
        url = [NSURL URLWithString:absoluteURLWithParams];
      }
      
      [self.webView loadRequest: [NSURLRequest requestWithURL:url]];
    } else if (![href hasPrefix:@"#"]) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"href must be null, a .html file or a #navigationhash"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
      return NO;
    } else {
      // it's a hash, so load the url without any possible current hash
      NSString *url = self.webView.request.URL.absoluteString;
      // remove the # if it's still there
      if ([url rangeOfString:@"#"].location != NSNotFound) {
        NSRange range = [url rangeOfString:@"#"];
        url = [url substringToIndex:range.location];
      }
      // attach the hash
      url = [url stringByAppendingString:href];
      // and load it
      [self.webView loadRequest: [NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    }
  }
  return YES;
}
@end
