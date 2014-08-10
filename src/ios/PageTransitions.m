#import "PageTransitions.h"

@implementation PageTransitions

- (void) slide:(CDVInvokedUrlCommand*)command {
  NSMutableDictionary *args = [command.arguments objectAtIndex:0];
  NSString *direction = [args objectForKey:@"direction"];
  NSTimeInterval duration = [[args objectForKey:@"duration"] doubleValue];
  NSString *file = [args objectForKey:@"file"];

  // duration is passed in ms, but needs to be in sec here
  duration = duration / 1000;

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

  if (file != nil) {
    NSString *filePath = [self.commandDelegate pathForResource:file];
    if (filePath == nil) {
      CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"file not found"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }

    NSURL *url = [NSURL fileURLWithPath: filePath];

    [self.webView loadRequest: [NSURLRequest requestWithURL:url]];
  }


  [UIView animateWithDuration:duration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     [_screenShotImageView setFrame:CGRectMake(transitionToX, transitionToY, width, height)];
                   }
                   completion:^(BOOL finished) {
                     [_screenShotImageView removeFromSuperview];
                     CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                     [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                   }];
}

@end
