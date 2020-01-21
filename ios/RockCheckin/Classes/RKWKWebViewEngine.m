//
//  RKWKWebViewEngine.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 9/10/18.
//

#import "RKWKWebViewEngine.h"

@implementation RKWKWebViewEngine

/**
 Initialize this class. If we are not on iOS 11 then return nil, which will cause a fallback
 to the UIWebView stuff.

 @param frame The frame to be used when creating the view
 @return A reference to the new web view engine or nil if not iOS 11 or later
 */
- (instancetype)initWithFrame:(CGRect)frame
{
    if (@available(iOS 11.0, *)) {
        self = [super initWithFrame:frame];
        
        return self;
    }
    else {
        return nil;
    }
}

/**
 Initialize the plugin and prepare for displaying web content
 */
- (void)pluginInitialize
{
    [super pluginInitialize];
    
    WKWebView *webView = (WKWebView *)self.engineWebView;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
 
    //
    // We will always be on iOS 11 or later, but this shuts up some compile warning. Add a filter to block
    // loading of the cordova.js file.
    //
    if (@available(iOS 11.0, *)) {
        id rules = @"[{\"trigger\": { \"resoure-type\": \"script\", \"url-filter\": \"http.*cordova-.*.js\" }, \"action\": { \"type\": \"block\" } }]";
        
        [WKContentRuleListStore.defaultStore compileContentRuleListForIdentifier:@"CordovaBlockingRules" encodedContentRuleList:rules completionHandler:^(WKContentRuleList *rules, NSError *error) {
            [webView.configuration.userContentController addContentRuleList:rules];
            dispatch_semaphore_signal(sema);
        }];
    }
    
    [webView.configuration.userContentController addScriptMessageHandler:(id < WKScriptMessageHandler >)self.viewController name:@"RockCheckinNative"];

    //
    // Inject our native bridge code.
    //
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"www/RockCheckinNative" ofType:@"js"];
    NSString *tJs = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:NULL];
    WKUserScript *nativeBridgeScript = [[WKUserScript alloc] initWithSource:tJs
                                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                           forMainFrameOnly:YES];
    [webView.configuration.userContentController addUserScript:nativeBridgeScript];

    //
    // Wait for the completion handler to run.
    //
    while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

@end
