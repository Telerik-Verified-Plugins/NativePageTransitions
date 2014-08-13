#import "PageTransitions.h"

@implementation PageTransitions

- (void) slide:(CDVInvokedUrlCommand*)command {
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
  
  if ([direction isEqualToString:@"left"]) {
    transitionToX = -width;
  } else if ([direction isEqualToString:@"right"]) {
    transitionToX = width;
  } else if ([direction isEqualToString:@"up"]) {
    transitionToY = -height;
  } else if ([direction isEqualToString:@"down"]) {
    transitionToY = height;
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
  [UIApplication.sharedApplication.keyWindow.subviews.lastObject addSubview:_screenShotImageView];

  // TODO deal with #hashes like Android does, may work though.. needs testing
  if (href != nil) {
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
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }
    
    NSURL *url = [NSURL fileURLWithPath: filePath];
    // re-attach the params when loading the url
    if (urlParams != nil) {
      NSString *absoluteURLString = [url absoluteString];
      NSString *absoluteURLWithParams = [absoluteURLString stringByAppendingString: urlParams];
      url = [NSURL URLWithString:absoluteURLWithParams];
    }
    
    [self.webView loadRequest: [NSURLRequest requestWithURL:url]];
  }
  
  [UIView animateWithDuration:duration
                        delay:delay
                      options:UIViewAnimationOptionCurveEaseInOut // TODO: allow passing in?
                   animations:^{
                     [_screenShotImageView setFrame:CGRectMake(transitionToX, transitionToY, width, height)];
                   }
                   completion:^(BOOL finished) {
                     [_screenShotImageView removeFromSuperview];
                     CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                     [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                   }];
  
  
  // included the code below for the 'push' animation, divide transitionX and Y for a more subtle effect
  [self.webView setFrame:CGRectMake(-transitionToX/[slowdownfactor intValue], -transitionToY/[slowdownfactor intValue], width, height)];
  
  [UIView animateWithDuration:duration
                        delay:delay
                      options:UIViewAnimationOptionCurveEaseInOut // property?
                   animations:^{
                     [self.webView setFrame:CGRectMake(0, 0, width, height)];
                   }
                   completion:^(BOOL finished) {
                   }];
}

@end
