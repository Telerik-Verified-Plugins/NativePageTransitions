#import "NativePageTransitions.h"

@implementation NativePageTransitions

- (void) flip:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSString *href = [args objectForKey:@"href"];

  // duration/delay is passed in ms, but needs to be in sec here
  duration = duration / 1000;

  UIViewAnimationOptions animationOptions;
  if ([direction isEqualToString:@"left"]) {
    animationOptions = UIViewAnimationOptionTransitionFlipFromLeft;
  } else if ([direction isEqualToString:@"right"]) {
    animationOptions = UIViewAnimationOptionTransitionFlipFromRight;
  } else if ([direction isEqualToString:@"up"]) {
    animationOptions = UIViewAnimationOptionTransitionFlipFromTop;
  } else if ([direction isEqualToString:@"down"]) {
    animationOptions = UIViewAnimationOptionTransitionFlipFromBottom;
  } else {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"direction should be one of up|down|left|right"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    return;
  }
  
  if ([self loadHrefIfPassed:href]) {
    [UIView transitionWithView:self.viewController.view
                    duration:duration
                     options:animationOptions | UIViewAnimationOptionAllowAnimatedContent // that last bit prevents screenshot-based animation (https://developer.apple.com/library/ios/documentation/windowsviews/conceptual/viewpg_iphoneos/animatingviews/animatingviews.html)
                  animations:^{}
                  completion:^(BOOL finished) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                  }];
  }
}

- (void) slide:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSString *href = [args objectForKey:@"href"];
  NSNumber *slowdownfactor = [args objectForKey:@"slowdownfactor"];

  // duration/delay is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;
  
  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  
  CGFloat transitionToX = 0;
  CGFloat transitionToY = 0;
  int screenshotSlowdownFactor = 1;
  int webviewSlowdownFactor = 1;
  
  if ([direction isEqualToString:@"left"]) {
    transitionToX = -width;
    screenshotSlowdownFactor = [slowdownfactor intValue];
  } else if ([direction isEqualToString:@"right"]) {
    transitionToX = width;
    webviewSlowdownFactor = [slowdownfactor intValue];
  } else if ([direction isEqualToString:@"up"]) {
    transitionToY = -height;
    screenshotSlowdownFactor = [slowdownfactor intValue];
  } else if ([direction isEqualToString:@"down"]) {
    transitionToY = height;
    webviewSlowdownFactor = [slowdownfactor intValue];
  }
  
  CGSize viewSize = self.viewController.view.bounds.size;
  UIGraphicsBeginImageContextWithOptions(viewSize, NO, 1.0);
  [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];
  
  _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
  [_screenShotImageView setImage:image];
  if ([direction isEqualToString:@"left"] || [direction isEqualToString:@"up"]) {
    [UIApplication.sharedApplication.keyWindow.subviews.lastObject insertSubview:_screenShotImageView belowSubview:self.webView];
  } else {
    [UIApplication.sharedApplication.keyWindow.subviews.lastObject insertSubview:_screenShotImageView aboveSubview:self.webView];
  }

  if ([self loadHrefIfPassed:href]) {
  [UIView animateWithDuration:duration
                        delay:delay
                      options:UIViewAnimationOptionCurveEaseInOut // TODO: allow passing in?
                   animations:^{
                     [_screenShotImageView setFrame:CGRectMake(transitionToX/screenshotSlowdownFactor, transitionToY/screenshotSlowdownFactor, width, height)];
                   }
                   completion:^(BOOL finished) {
                     [_screenShotImageView removeFromSuperview];
                     CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                     [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                   }];
  
  
  // included the code below for the 'push' animation, divide transitionX and Y for a more subtle effect
  [self.webView setFrame:CGRectMake(-transitionToX/webviewSlowdownFactor, -transitionToY/webviewSlowdownFactor, width, height)];
  
  [UIView animateWithDuration:duration
                        delay:delay
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     [self.webView setFrame:CGRectMake(0, 0, width, height)];
                   }
                   completion:^(BOOL finished) {
                   }];
  }
}


- (void) drawer:(CDVInvokedUrlCommand*)command {
  _command = command;
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *action = [args objectForKey:@"action"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSTimeInterval delay = [[args objectForKey:@"iosdelay"] doubleValue];
  NSString *href = [args objectForKey:@"href"];
  
  // duration/delay is passed in ms, but needs to be in sec here
  duration = duration / 1000;
  delay = delay / 1000;
  
  CGFloat width = self.viewController.view.frame.size.width;
  CGFloat height = self.viewController.view.frame.size.height;
  
  CGFloat transitionToX = 0;
  
  if ([action isEqualToString:@"open"]) {
    transitionToX = width-44;
  } else if ([action isEqualToString:@"close"]) {
    transitionToX = -(width-44);
  }
  
  CGSize viewSize = self.viewController.view.bounds.size;
  UIGraphicsBeginImageContextWithOptions(viewSize, NO, 1.0);
  [self.viewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
  
  // Read the UIImage object
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  [_screenShotImageView setFrame:CGRectMake(0, 0, width, height)];
  if ([action isEqualToString:@"open"]) {
    _screenShotImageView = [[UIImageView alloc]initWithFrame:[self.viewController.view.window frame]];
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
    [UIApplication.sharedApplication.keyWindow.subviews.lastObject insertSubview:_screenShotImageView aboveSubview:self.webView];
  } else {
//    [UIApplication.sharedApplication.keyWindow.subviews.lastObject insertSubview:_screenShotImageView belowSubview:self.webView];
    [UIApplication.sharedApplication.keyWindow.subviews.lastObject bringSubviewToFront:self.webView];
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
                         [_screenShotImageView removeFromSuperview];
                       }
                       CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                       [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                     }];
    }
    
    // included the code below for the 'push' animation, divide transitionX and Y for a more subtle effect
    if ([action isEqualToString:@"close"]) {
      [self.webView setFrame:CGRectMake(width-44, 0, width, height)];
    
      [UIView animateWithDuration:duration
                            delay:delay
                          options:UIViewAnimationOptionCurveEaseInOut
                       animations:^{
                         [self.webView setFrame:CGRectMake(0, 0, width, height)];
                       }
                       completion:^(BOOL finished) {
                            [_screenShotImageView removeFromSuperview];
                            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
    }
  }
}

- (BOOL) loadHrefIfPassed:(NSString*) href {
  if (href != nil) {
    if ([href rangeOfString:@".html"].location != NSNotFound) {
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
      // attach the hash
      url = [url stringByAppendingString:href];
      // and load it
      [self.webView loadRequest: [NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    }
  }
  return YES;
}
@end
