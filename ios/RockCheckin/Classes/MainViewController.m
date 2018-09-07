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
#import <WebKit/WebKit.h>

@implementation MainViewController

- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    [BlockOldRockRequests enable];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoadNotification:) name:CDVPageDidLoadNotification object:nil];

    return self;
}


- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (id)init
{
    self = [super init];

    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
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
- (void)injectJavascriptFile:(NSString *)resource intoWebView:(WKWebView *)webView
{
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:resource ofType:@"js"];
    NSString *js = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:NULL];
    
    [webView evaluateJavaScript:js completionHandler:nil];
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
    WKWebView *webView = (WKWebView *)notification.object;
    
    [self injectJavascriptFile:@"www/cordova" intoWebView:webView];
    [self injectJavascriptFile:@"www/cordova_plugins" intoWebView:webView];
    
    NSArray* pluginObjects = [self parseCordovaPlugins];
    for (NSDictionary* pluginParameters in pluginObjects) {
        NSString* path = [[NSString stringWithFormat:@"www/%@", pluginParameters[@"file"]] stringByDeletingPathExtension];
        
        [self injectJavascriptFile:path intoWebView:webView];
    }
}


#pragma mark View lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    // View defaults to full size.  If you want to customize the view's size, or its subviews (e.g. webView),
    // you can do so here.

    [super viewWillAppear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

@end

