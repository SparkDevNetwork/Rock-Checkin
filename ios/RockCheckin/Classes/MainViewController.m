/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

//
//  MainViewController.h
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//  Copyright Spark Development 2013. All rights reserved.
//

#import "MainViewController.h"
#import "SettingsViewController.h"
#import "CameraViewController.h"
#import "RKNativeJSBridge.h"
#import "RKNativeJSCommand.h"
#import "WKWebViewUIDelegate.h"
#import "ZebraPrint.h"
#import <WebKit/WebKit.h>
#import "SettingsHelper.h"

@interface MainViewController () <UIGestureRecognizerDelegate, WKNavigationDelegate, CameraViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UILongPressGestureRecognizer *settingsGestureRecognizer;

@property (strong, nonatomic) WKWebView *webView;
@property (strong, nonatomic) WKWebViewUIDelegate *uiDelegate;
@property (strong, nonatomic) CameraViewController *cameraViewController;
@property (strong, nonatomic) RKNativeJSBridge *nativeBridge;
@property (assign, nonatomic) BOOL passiveMode;

@end


@implementation MainViewController


/**
 Initialize the view controller with the specified NIB file and bundle.
 */
- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    self.webView = [WKWebView new];
    self.webView.navigationDelegate = self;
    if (@available(iOS 16.4, *)) {
        self.webView.inspectable = YES;
    }
    self.webView.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:self.webView];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];

    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"RockCheckinNative"];

    //
    // Inject our native bridge code.
    //
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"www/RockCheckinNative" ofType:@"js"];
    NSString *tJs = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:NULL];
    WKUserScript *nativeBridgeScript = [[WKUserScript alloc] initWithSource:tJs
                                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                           forMainFrameOnly:YES];
    [self.webView.configuration.userContentController addUserScript:nativeBridgeScript];

    self.nativeBridge = [[RKNativeJSBridge alloc] initWithMainController:self];
    
    self.uiDelegate = [[WKWebViewUIDelegate alloc] initWithTitle:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
    self.webView.UIDelegate = self.uiDelegate;

    return self;
}


/**
 The view has been loaded, set any initial settings.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.settingsGestureRecognizer.enabled = [SettingsHelper boolForKey:@"in_app_settings"];
    self.settingsGestureRecognizer.minimumPressDuration = [SettingsHelper integerForKey:@"in_app_settings_delay"];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(defaultsChangedNotification:)
                                               name:NSUserDefaultsDidChangeNotification
                                             object:nil];
}


/**
 Indicate to the system that we want the status bar to be hidden.
 */
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


/**
 Reloads the web view with the URL specified in the preferences.
 */
- (void)reloadCheckinAddress
{
    NSURL *url = [NSURL URLWithString:[SettingsHelper objectForKey:@"checkin_address"]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self.webView loadRequest:request];
}


/**
 Shows the barcode scanning camera.
*/
- (void)startCamera:(BOOL)passive
{
    [self stopCamera];
    
    self.cameraViewController = [CameraViewController new];
    self.cameraViewController.delegate = self;

    if (passive) {
        [self addChildViewController:self.cameraViewController];
        self.cameraViewController.view.hidden = YES;
        [self.view addSubview:self.cameraViewController.view];
        [self.cameraViewController didMoveToParentViewController:self];
    }
    else {
        // Force the view to load.
        [self.cameraViewController view];
        [self.navigationController pushViewController:self.cameraViewController animated:YES];
    }

    self.passiveMode = passive;
    
    [self.cameraViewController start];
}

/**
 Hides the camera view, or if it's passive then turn it off.
 */
- (void)stopCamera
{
    if (self.cameraViewController == nil )
    {
        return;
    }

    [self.cameraViewController stop];
    
    if (self.cameraViewController.view.hidden) {
        [self.cameraViewController willMoveToParentViewController:nil];
        [self.cameraViewController.view removeFromSuperview];
        self.cameraViewController.view.hidden = NO;
        [self.cameraViewController removeFromParentViewController];
    }
    else if (self.navigationController.topViewController == self.cameraViewController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    self.cameraViewController = nil;
    
    //
    // If we were in passive mode before, then return to passive mode.
    //
    if (self.passiveMode) {
        [self startCamera:YES];
    }
}


/**
 User defaults have changed, check if the in-app settings toggle has changed
 
 @param notification The notification information that caused us to be called
 */
- (void)defaultsChangedNotification:(NSNotification *)notification
{
    self.settingsGestureRecognizer.enabled = [SettingsHelper boolForKey:@"in_app_settings"];
    self.settingsGestureRecognizer.minimumPressDuration = [SettingsHelper integerForKey:@"in_app_settings_delay"];
}

/**
 A plugin has reset, if it's the webview then turn off the camera as that indicates the start
 of a page load.
 
 @param notification The notification information that caused us to be called
 */
- (void)pluginResetNotification:(NSNotification *)notification
{
    if (notification.object == self.webView) {
        self.passiveMode = NO;
        [self stopCamera];
    }
}


/**
 User has activated the gesture to show the in-app settings screen

 @param sender The gesture recognizer that has triggered us
 */
- (IBAction)showSettingsViewController:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.navigationController pushViewController:[SettingsViewController new] animated:YES];
    }
}


#pragma mark Javascript Injection

/**
 Execute the specified  JavaScript in the web view.
 
 @param  js The JavaScript text to be executed.
 */
- (void)evaluateScript:(NSString *)js
{
    if ([self.webView isKindOfClass:[WKWebView class]])
    {
        //
        // WKWebView processes JavaScript asynchronously, so we need to do
        // some special work to pause processing until it has completed.
        //
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        [(WKWebView *)self.webView evaluateJavaScript:js completionHandler:^(id _Nullable ignored, NSError * _Nullable error) {
            dispatch_semaphore_signal(sema);
        }];

        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    }
}


#pragma mark UIGestureRecognizerDelegate


/**
 Determines if our custom gesture recognizer for settings should attempt to recognize along with
 the other gesture recognizer.

 @param gestureRecognizer Our gesture recognizer
 @param otherGestureRecognizer The other gesture recognizer that is alos running
 @return YES - always run together
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}


#pragma mark WKScriptMessageHandler implementation

- (void)userContentController:(WKUserContentController*)userContentController didReceiveScriptMessage:(WKScriptMessage*)message
{
    if (![message.name isEqualToString:@"RockCheckinNative"]) {
        return;
    }
    
    NSDictionary *paramDict = message.body;
    NSString *promiseId = paramDict[@"promiseId"];
    NSString *name = paramDict[@"name"];
    NSArray *arguments = paramDict[@"data"];
    
    RKNativeJSCommand *command = [[RKNativeJSCommand alloc] initWithPromise:promiseId
                                                                       name:name
                                                                  arguments:arguments];
    command.webKitView = (WKWebView *)self.webView;
    
    [command executeWithBridge:self.nativeBridge];
}


#pragma mark WKNavigationDelegate implementation

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    self.passiveMode = NO;
    [self stopCamera];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if (self.readyDelegate != nil) {
        [self.readyDelegate mainViewControllerIsReady];
    }
}


#pragma mark CameraViewControllerDelegate implementation

/**
 Called when the camera view has detected a generic barcode.
 
 @param controller The camera view controller that scanned the barcode.
 @param code The code that was scanned.
 */
- (void)cameraViewController:(CameraViewController *)controller didScanGenericCode:(NSString *)code
{
    [self evaluateScript:[NSString stringWithFormat:@"PerformScannedCodeSearch('%@');", code]];
    
    //
    // Make sure we don't start up in passive mode again.
    //
    self.passiveMode = NO;
    
    [self stopCamera];
}

/**
 Called when a pre-check-in code has been scanned and must be processed.
 
 @param controller The camera view controller that scanned the barcode.
 @param code The code that was scanned.
 @param callback The completion callback that must be called when printing has finished.
 */
- (void)cameraViewController:(CameraViewController *)controller didScanPreCheckInCode:(NSString *)code completedCallback:(void (^)(NSString *))callback
{
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:[SettingsHelper objectForKey:@"checkin_address"]];
    urlComponents.path = @"/api/checkin/printsessionlabels";
    NSURLQueryItem *kioskIdParam = [NSURLQueryItem  queryItemWithName:@"kioskId" value:[NSString stringWithFormat:@"%d", self.kioskId]];
    NSURLQueryItem *sessionParam = [NSURLQueryItem queryItemWithName:@"session" value:code];
    urlComponents.queryItems = @[kioskIdParam, sessionParam];

    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:urlComponents.URL];
    NSURLSession *session = NSURLSession.sharedSession;
    
    NSURLSessionDataTask *requestTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        @try {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 200) {
                NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                NSArray *labels = nil;
                if ([responseData objectForKey:@"Labels"] != NSNull.null) {
                    labels = (NSArray *)[responseData objectForKey:@"Labels"];
                }

                NSArray *messages = nil;
                if ([responseData objectForKey:@"Messages"] != NSNull.null) {
                    messages = (NSArray *)[responseData objectForKey:@"Messages"];
                }

                NSString *errorMessage = nil;
                if (messages != nil && messages.count > 0) {
                    errorMessage = (NSString *)messages[0];
                }
                
                if (labels != nil && labels.count > 0) {
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:labels options:0 error:nil];
                    
                    ZebraPrint *zebra = [ZebraPrint new];
                    errorMessage = [zebra printJsonTags:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
                }

                callback(errorMessage);
            }
            else
            {
                callback(@"Unable to contact the check-in server.");
            }
        } @catch (NSException *exception) {
            NSLog(@"Error while printing: %@", exception);
            
            callback(@"Unable to print check-in labels.");
        }
    }];
    
    [requestTask resume];
}

/**
 Called when the camera view wants to cancel itself.
 
 @param controller The camera view controller that should be cancelled.
 */
- (void)cameraViewControllerDidCancel:(CameraViewController *)controller
{
    [self stopCamera];
}

@end

