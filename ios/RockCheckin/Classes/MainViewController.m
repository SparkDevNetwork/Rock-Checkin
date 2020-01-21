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
#import "BlockOldRockRequests.h"
#import "SettingsViewController.h"
#import "CameraViewController.h"
#import "RKNativeJSBridge.h"
#import "RKNativeJSCommand.h"
#import <WebKit/WebKit.h>

@interface MainViewController () <UIGestureRecognizerDelegate, CameraViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UILongPressGestureRecognizer *settingsGestureRecognizer;

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

    self.nativeBridge = [[RKNativeJSBridge alloc] initWithMainController:self];
    
    [BlockOldRockRequests enable];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoadNotification:) name:CDVPageDidLoadNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pluginResetNotification:) name:CDVPluginResetNotification object:nil];

    return self;
}


/**
 The view has been loaded, set any initial settings.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.settingsGestureRecognizer.enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"in_app_settings"];
    self.settingsGestureRecognizer.minimumPressDuration = [NSUserDefaults.standardUserDefaults integerForKey:@"in_app_settings_delay"];

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
    NSURL *url = [NSURL URLWithString:[NSUserDefaults.standardUserDefaults objectForKey:@"checkin_address"]];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [self.webViewEngine loadRequest:request];
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
    self.settingsGestureRecognizer.enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"in_app_settings"];
    self.settingsGestureRecognizer.minimumPressDuration = [NSUserDefaults.standardUserDefaults integerForKey:@"in_app_settings_delay"];
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

/*
 These methods were taken from a defunct cordova plugin at
 https://github.com/fastrde/cordova-plugin-fastrde-injectview
 */

/**
 Inject a javascript file directly into the webView. This bypasses cross site restrictions.
 
 @param resource The name of the resource (not including extension) to load.
 @param webView The UIWebView to load the javascript into.
 */
- (void)injectJavascriptFiles:(NSArray *)resources intoWebView:(UIView *)webView
{
    NSString *js = @"";
    
    //
    // Build one giant JavaScript string that contains the contents of
    // all the files.
    //
    for (NSString *resource in resources) {
        NSString *jsPath = [[NSBundle mainBundle] pathForResource:resource ofType:@"js"];
        NSString *tJs = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:NULL];
        js = [js stringByAppendingFormat:@";%@", tJs];
    }
    
    [self evaluateScript:js];
}

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
    else if ([self.webView isKindOfClass:[UIWebView class]])
    {
        [(UIWebView *)self.webView stringByEvaluatingJavaScriptFromString:js];
    }
}


/**
 Extract the JSON object data from the cordova_plugins file.
 
 @return Array of plugin object definitations
 */
- (NSArray*)parseCordovaPlugins
{
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"www/cordova_plugins" ofType:@"js"];
    NSString *js = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:NULL];
    NSScanner *scanner = [NSScanner scannerWithString:js];
    NSString *substring = nil;
    
    [scanner scanUpToString:@"[" intoString:nil];
    [scanner scanUpToString:@"];" intoString:&substring];
    substring = [NSString stringWithFormat:@"%@]", substring];
    
    NSError* localError;
    NSData* data = [substring dataUsingEncoding:NSUTF8StringEncoding];
    NSArray* pluginObjects = [NSJSONSerialization JSONObjectWithData:data options:0 error:&localError];
    
    return pluginObjects;
}


#pragma mark Notifications

/**
 UIWebView has finished loading a page. Inject the cordova scripts.
 
 @param notification Notification that caused this invocation.
 */
- (void)pageDidLoadNotification:(NSNotification *)notification
{
    UIView *webView = (UIView *)notification.object;
    NSMutableArray *paths = [NSMutableArray arrayWithObjects:@"www/cordova", @"www/cordova_plugins", nil];
    
    NSArray* pluginObjects = [self parseCordovaPlugins];
    for (NSDictionary* pluginParameters in pluginObjects) {
        [paths addObject:[[NSString stringWithFormat:@"www/%@", pluginParameters[@"file"]] stringByDeletingPathExtension]];
    }

    [self injectJavascriptFiles:paths intoWebView:webView];
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


#pragma mark CameraViewControllerDelegate implementation

/**
 Called when the camera view has detected a barcode.
 @param controller The camera view controller that scanned the barcode.
 @param code The code that was scanned.
 */
- (void)cameraViewController:(CameraViewController *)controller didScanCode:(NSString *)code
{
    [self evaluateScript:[NSString stringWithFormat:@"PerformScannedCodeSearch('%@');", code]];
    
    //
    // Make sure we don't start up in passive mode again.
    //
    self.passiveMode = NO;
    
    [self stopCamera];
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

