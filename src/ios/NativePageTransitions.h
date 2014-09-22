#import "Cordova/CDV.h"

@interface NativePageTransitions : CDVPlugin

@property (strong, nonatomic) IBOutlet UIImageView *screenShotImageView;

- (void) slide:(CDVInvokedUrlCommand*)command;

@end