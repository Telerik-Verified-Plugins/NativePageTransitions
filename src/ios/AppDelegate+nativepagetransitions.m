#import "AppDelegate+nativepagetransitions.h"
#import "NativePageTransitions.h"

@implementation AppDelegate (nativepagetransitions)

- (void)application:(UIApplication *)application willChangeStatusBarFrame:(CGRect)newStatusBarFrame {
    if (self.viewController.webView != nil) {
        NativePageTransitions *nativeTransitions = [self.viewController getCommandInstance:@"NativePageTransitions"];
        nativeTransitions.webViewPushedDownPixels = newStatusBarFrame.size.height;
    }
}

@end