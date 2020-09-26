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
//  AppDelegate.m
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//  Copyright Spark Development 2013. All rights reserved.
//

#import "AppDelegate.h"
#import "MainViewController.h"

#import <WebKit/WebKit.h>
#import "RKBLEZebraPrint.h"
#import "SettingsViewController.h"
#import "InitialSetupViewController.h"

static AppDelegate *_sharedDelegate = nil;

@implementation AppDelegate

@synthesize window, viewController;


/**
 Gets the shared application delegate for this run instance.
 
 @return The AppDelegate object.
 */
+ (AppDelegate *)sharedDelegate
{
    return _sharedDelegate;
}


/**
 Initialize the app delegate

 @return A reference to this object
 */
- (id)init
{
    /** If you need to do any extra app-specific initialization, you can do it here
     *  -jm
     **/
    NSHTTPCookieStorage* cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];

    [cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    self = [super init];
    _sharedDelegate = self;
    
    return self;
}


/**
 User defaults have changed, check if we need to reconnect to the printer

 @param notification The notification information that caused us to be called
 */
- (void)defaultsChangedNotification:(NSNotification *)notification
{
    NSString *printerName = [[NSUserDefaults standardUserDefaults] stringForKey:@"printer_override"];
    
    if (printerName != nil && printerName.length > 0 && [NSUserDefaults.standardUserDefaults boolForKey:@"bluetooth_printing"]) {
        if (![printerName isEqualToString:self.blePrinter.printerName]) {
            [self.blePrinter setPrinterName:printerName];
        }
    }
    else {
        [self.blePrinter setPrinterName:nil];
    }
}


/**
 Make sure all our user defaults have been registered so when we later
 retrieve them we get a valid value.
 */
- (void)registerUserDefaults
{
    NSString *pathStr = [[NSBundle mainBundle] bundlePath];
    NSString *settingsBundlePath = [pathStr stringByAppendingPathComponent:@"Settings.bundle"];
    NSString *finalPath = [settingsBundlePath stringByAppendingPathComponent:@"Root.plist"];
    
    NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:finalPath];
    NSArray *prefSpecifierArray = [settingsDict objectForKey:@"PreferenceSpecifiers"];

    //
    // Loop through the array of preference specifiers and build a dictionary
    // of what our default values will be.
    //
    NSMutableDictionary *defaultValues = [NSMutableDictionary new];
    for (NSDictionary *prefItem in prefSpecifierArray)
    {
        if ([prefItem objectForKey:@"Key"] != nil && [prefItem objectForKey:@"DefaultValue"] != nil) {
            [defaultValues setObject:[prefItem objectForKey:@"DefaultValue"] forKey:[prefItem objectForKey:@"Key"]];
        }
    }
    
    [NSUserDefaults.standardUserDefaults registerDefaults:defaultValues];

    // Set any settings pushed from MDM
    NSDictionary *serverConfig = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"com.apple.configuration.managed"];
    if(serverConfig == nil) {
        serverConfig = @{};
    }
    for(id key in serverConfig) {
        [NSUserDefaults.standardUserDefaults setObject:[serverConfig objectForKey:key] forKey:key];
    }
}


#pragma mark UIApplicationDelegate implementation

/**
 * This is main kick off after the app inits, the views and Settings are setup here. (preferred - iOS4 and up)
 */
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    [self registerUserDefaults];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(defaultsChangedNotification:)
                                               name:NSUserDefaultsDidChangeNotification
                                             object:nil];
    
    //
    // Create the primary window and primary view controller.
    //
    self.window = [[UIWindow alloc] initWithFrame:screenBounds];
    self.window.autoresizesSubviews = YES;
    self.viewController = [[UINavigationController alloc] initWithRootViewController:[InitialSetupViewController new]];
    self.viewController.navigationBarHidden = YES;

    //
    // Show everything on screen.
    //
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];

    //
    // Initialize the bluetooth printer and set the default printer if
    // Bluetooth Printing is enabled.
    //
    self.blePrinter = [[RKBLEZebraPrint alloc] init];
    NSString *printerName = [[NSUserDefaults standardUserDefaults] stringForKey:@"printer_override"];
    if (printerName != nil && printerName.length > 0 && [NSUserDefaults.standardUserDefaults boolForKey:@"bluetooth_printing"])
    {
        [self.blePrinter setPrinterName:printerName];
    }

    return YES;
}

/**
 Specify which orientations our application supports. This takes precedence over any
 specific view controller's supported orientations.

 @param application The application
 @param window The window to be rotated
 @return A mask of interface orientations.
 */
- (UIInterfaceOrientationMask)application:(UIApplication*)application supportedInterfaceOrientationsForWindow:(UIWindow*)window
{
    // iPhone doesn't support upside down by default, while the iPad does.  Override to allow all orientations always, and let the root view controller decide what's allowed (the supported orientations mask gets intersected).
    UIInterfaceOrientationMask supportedInterfaceOrientations = (1 << UIInterfaceOrientationPortrait) | (1 << UIInterfaceOrientationLandscapeLeft) | (1 << UIInterfaceOrientationLandscapeRight) | (1 << UIInterfaceOrientationPortraitUpsideDown);

    return supportedInterfaceOrientations;
}


@end
