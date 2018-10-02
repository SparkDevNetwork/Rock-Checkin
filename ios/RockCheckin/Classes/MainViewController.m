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
#import <WebKit/WebKit.h>

@implementation MainViewController


/**
 Initialize the view controller with the specified NIB file and bundle.
 */
- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    [BlockOldRockRequests enable];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoadNotification:) name:CDVPageDidLoadNotification object:nil];

    return self;
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
    
    if ([webView isKindOfClass:[WKWebView class]])
    {
        //
        // WKWebView processes JavaScript asynchronously, so we need to do
        // some special work to pause processing until it has completed.
        //
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);

        [(WKWebView *)webView evaluateJavaScript:js completionHandler:^(id _Nullable ignored, NSError * _Nullable error) {
            dispatch_semaphore_signal(sema);
        }];

        while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        }
    }
    else if ([webView isKindOfClass:[UIWebView class]])
    {
        [(UIWebView *)webView stringByEvaluatingJavaScriptFromString:js];
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

@end
