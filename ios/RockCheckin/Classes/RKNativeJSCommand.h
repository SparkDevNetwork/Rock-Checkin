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
//  RKNativeJSCommand.h
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 1/20/20.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RKNativeJSBridge;

@interface RKNativeJSCommand : NSObject

#pragma mark Properties

/**
 The WebKit view that this command came  from.
 */
@property (strong, nonatomic) WKWebView *webKitView;

/**
 The name of the command to be executed.
 */
@property (strong, nonatomic) NSString *name;

/**
 The JavaScript promise identifier for this command.
 */
@property (strong, nonatomic) NSString *promiseId;

/**
 The arguments passed from JavaScript.
 */
@property (strong, nonatomic) NSArray *arguments;


#pragma mark Methods

/**
 Initialize a new native JavaScript command reference.
 
 @param promiseId The JavaScript promise identifier for this command.
 @param name The name of the command to be executed.
 @param arguments The arguments that were passed from JavaScript.
 */
- (id)initWithPromise:(NSString *)promiseId name:(NSString *)name arguments:(NSArray *)arguments;

/**
 Executes this command with the specified bridge object.
 
 @param bridge The bridge object that contains methods to be executed.
 */
- (void)executeWithBridge:(id)bridge;


/**
 Send back a success result with no parameters.
 */
- (void)sendSuccess;

/**
 Send back a success result with a string as the response parameter.
 
 @param response The string to be sent back as the first JavaScript parameter.
 */
- (void)sendSuccessString:(NSString *)response;

/**
 Send back a success result with the specified dictionary as the first JavaScript parameter.
 
 @param response The dictionary to be conerted into JSON notation and sent back as the first JavaScript parameter.
 */
- (void)sendSuccessObject:(NSDictionary *)response;


/**
 Send back an error result with no parameters.
 */
- (void)sendError;

/**
 Send back an error result with a string as the response parameter.
 
 @param response The string to be sent back as the first JavaScript parameter.
 */
- (void)sendErrorString:(NSString *)response;

/**
 Send back an error result with the specified dictionary as the first JavaScript parameter.
 
 @param response The dictionary to be conevrted into JSON notation and sent back as the first JavaScript parameter.
 */
- (void)sendErrorObject:(NSDictionary *)response;

@end

NS_ASSUME_NONNULL_END
