#import "Cordova/CDV.h"

@interface PageTransitions : CDVPlugin

@property (strong, nonatomic) IBOutlet UIImageView *screenShotImageView;

- (void) slide:(CDVInvokedUrlCommand*)command;

@end