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
//  RKNativeJSBridge.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 1/19/20.
//

#import "RKNativeJSBridge.h"
#import "RKNativeJSCommand.h"
#import "ZebraPrint.h"

@interface RKNativeJSBridge ()

@property (weak, nonatomic) MainViewController *mainViewController;

@end

@implementation RKNativeJSBridge

/**
Initialize a new RKNativeJSBridge object that will be owned by the main view controller.

@param controller The MainViewController to pass messages along to.
*/
- (id)initWithMainController:(MainViewController *)controller
{
    if ((self = [self init]) == nil)
    {
        return nil;
    }
    
    self.mainViewController = controller;
    
    return self;
}


/**
 Handles the PrintLabels command from JavaScript.
 
 @param command The native JavaScript command details.
 */
- (void)PrintLabels:(RKNativeJSCommand *)command
{
    ZebraPrint *zebra = [ZebraPrint new];
    
    NSString *errorMessage = [zebra printJsonTags:(NSString *)command.arguments.firstObject];
    
    if (errorMessage == nil) {
        [command sendSuccess];
    }
    else {
        [command sendErrorObject:@{ @"Error": errorMessage, @"CanReprint": @NO}];
    }
}


/**
Handles the StartCamera command from JavaScript.

@param command The native JavaScript command details.
*/
- (void)StartCamera:(RKNativeJSCommand *)command
{
    BOOL passive = NO;
    
    if (command.arguments.count > 0)
    {
        passive = [command.arguments[0] boolValue];
    }

    [self.mainViewController startCamera:passive];
    
    [command sendSuccess];
}


/**
Handles the StopCamera command from JavaScript.

@param command The native JavaScript command details.
*/
- (void)StopCamera:(RKNativeJSCommand *)command
{
    [self.mainViewController stopCamera];
    
    [command sendSuccess];
}


/**
 Handles the SetKioskId command from JavaScript.
 
 @param command The native JavaScript command details.
 */
- (void)SetKioskId:(RKNativeJSCommand *)command
{
    self.mainViewController.kioskId = [command.arguments[0] intValue];
}

@end

