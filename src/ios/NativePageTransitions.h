#import "Cordova/CDV.h"

@interface NativePageTransitions : CDVPlugin

@property (strong, nonatomic) IBOutlet UIImageView *screenShotImageView;
@property (strong, nonatomic) IBOutlet CDVInvokedUrlCommand *command;

- (void) slide:(CDVInvokedUrlCommand*)command;
- (void) drawer:(CDVInvokedUrlCommand*)command;
- (void) flip:(CDVInvokedUrlCommand*)command;

@end