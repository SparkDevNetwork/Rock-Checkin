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
@property (strong, nonatomic) NSMutableArray *promiseWaiters;
@property (strong, nonatomic) NSLock *promiseWaitersLock;

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
    self.promiseWaiters = [[NSMutableArray alloc] init];
    self.promiseWaitersLock = [[NSLock alloc] init];
    
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
 Handles the PrintV2Labels command from JavaScript.
 
 @param command The native JavaScript command details.
 */
- (void)PrintV2Labels:(RKNativeJSCommand *)command
{
    ZebraPrint *zebra = [ZebraPrint new];
    
    NSArray *errorMessages = [zebra printLabels:(NSString *)command.arguments.firstObject];
    
    [command sendSuccessObject:errorMessages];
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

- (void)ResolvePromise:(RKNativeJSCommand *)command
{
    if (command.arguments.count == 0) {
        return;
    }

    RKPromiseWaiter *foundWaiter = nil;
    NSString *promiseId = command.arguments[0];
    id result = command.arguments[1];
    id errorMessage = command.arguments[2];
    
    if (result == NSNull.null) {
        result = nil;
    }
    
    if (errorMessage == NSNull.null) {
        errorMessage = nil;
    }
    
    [self.promiseWaitersLock lock];
    @try {
        for (int i = 0; i < self.promiseWaiters.count; i++) {
            RKPromiseWaiter *waiter = self.promiseWaiters[i];

            if ([waiter.promiseId isEqualToString:promiseId]) {
                foundWaiter = waiter;
                [self.promiseWaiters removeObjectAtIndex:i];
                break;
            }
        }
    }
    @finally {
        [self.promiseWaitersLock unlock];
    }
    
    if (foundWaiter != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            foundWaiter.callback(result, errorMessage);
        });
    }
}

- (RKPromiseWaiter *)createPromiseWaiterWithCompletionHandler:(WaiterCompletionBlock)callback
{
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
    
    [self.promiseWaitersLock lock];
    @try {
        // Look for any expired waiters.
        for (int i = 0; i < self.promiseWaiters.count; i++) {
            RKPromiseWaiter *existingWaiter = self.promiseWaiters[i];
            if (existingWaiter.expireAt < now) {
                [self.promiseWaiters removeObjectAtIndex:i];
                i--;
            }
        }

        RKPromiseWaiter *waiter = [[RKPromiseWaiter alloc] init];
        waiter.callback = callback;
        [self.promiseWaiters addObject:waiter];
        
        return waiter;
    }
    @finally {
        [self.promiseWaitersLock unlock];
    }
}

- (void)destroyPromiseWaiter:(RKPromiseWaiter *)waiter
{
    [self.promiseWaitersLock lock];
    @try {
        for (int i = 0; i < self.promiseWaiters.count; i++) {
            RKPromiseWaiter *waiter = self.promiseWaiters[i];

            if ([waiter.promiseId isEqualToString:waiter.promiseId]) {
                [self.promiseWaiters removeObjectAtIndex:i];
                return;
            }
        }
    }
    @finally {
        [self.promiseWaitersLock unlock];
    }
}

@end

@implementation RKPromiseWaiter

- (RKPromiseWaiter *)init
{
    if ((self = [super init]) == nil)
    {
        return nil;
    }
    
    self.promiseId = [[NSUUID UUID] UUIDString];
    self.expireAt = NSDate.timeIntervalSinceReferenceDate + 300;

    return self;
}

@end
