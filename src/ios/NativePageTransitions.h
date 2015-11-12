#import <WebKit/WebKit.h>
#import "Cordova/CDV.h"

@interface NativePageTransitions : CDVPlugin

@property (retain) NSMutableDictionary *slideOptions;
@property (retain) NSMutableDictionary *flipOptions;
@property (retain) NSMutableDictionary *drawerOptions;
@property (retain) NSMutableDictionary *fadeOptions;
@property (retain) NSMutableDictionary *curlOptions;

@property (retain) UIColor *originalColor;

@property (strong, nonatomic) IBOutlet UIImageView *screenShotImageViewTop;
@property (strong, nonatomic) IBOutlet UIImageView *screenShotImageViewBottom;
@property (strong, nonatomic) IBOutlet UIImageView *screenShotImageView;
@property (strong, nonatomic) IBOutlet CDVInvokedUrlCommand *command;

@property (strong, nonatomic) IBOutlet UIView *transitionView;
@property (strong, nonatomic) IBOutlet WKWebView *wkWebView;
@property (nonatomic, assign) int nonWebViewHeight;
@property (nonatomic, assign) int webViewPushedDownPixels;

- (void) slide:(CDVInvokedUrlCommand*)command;
- (void) drawer:(CDVInvokedUrlCommand*)command;
- (void) flip:(CDVInvokedUrlCommand*)command;
- (void) curl:(CDVInvokedUrlCommand*)command;
- (void) fade:(CDVInvokedUrlCommand*)command;

- (void) executePendingTransition:(CDVInvokedUrlCommand*)command;

@end