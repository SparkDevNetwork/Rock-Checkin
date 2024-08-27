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
//  RKNativeJSCommand.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 1/20/20.
//

#import "RKNativeJSCommand.h"
#import "RKNativeJSBridge.h"

@interface RKNativeJSCommand ()

@end

@implementation RKNativeJSCommand

/**
Initialize a new native JavaScript command reference.

@param promiseId The JavaScript promise identifier for this command.
@param name The name of the command to be executed.
@param arguments The arguments that were passed from JavaScript.
*/
- (id)initWithPromise:(NSString *)promiseId name:(NSString *)name arguments:(NSArray *)arguments
{
    if ((self = [super init]) == nil)
    {
        return nil;
    }
    
    self.promiseId = promiseId;
    self.name = name;
    self.arguments = arguments;
    
    return self;
}


/**
Executes this command with the specified bridge object.

@param bridge The bridge object that contains methods to be executed.
*/
- (void)executeWithBridge:(id)bridge
{
    SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%@:", self.name]);
    if (![bridge respondsToSelector:sel]) {
        [self sendErrorString:@"Native method not found."];
        
        return;
    }
    
    void (*fn)(id, SEL, RKNativeJSCommand *) = (void *)[bridge methodForSelector:sel];
    
    fn(bridge, sel, self);
}


/**
 Sends back a response with the specified JSON string as the parameter.
 
 @param json The raw string to send back as the JavaScript parameter.
 @param error If YES then the response will indicate an error.
 */
- (void)sendResponseJson:(NSString *)json error:(BOOL)error
{
    NSString *fn = @"RockCheckinNative.ResolveNativePromise";
    NSString *javascript;
    
    if (error) {
        javascript = [NSString stringWithFormat:@"%@('%@', %@, true);", fn, self.promiseId, json];
    }
    else {
        javascript = [NSString stringWithFormat:@"%@('%@', %@, false);", fn, self.promiseId, json];
    }
    
    [self.webKitView evaluateJavaScript:javascript completionHandler:nil];
}


/**
Send back a success result with no parameters.
*/
- (void)sendSuccess
{
    [self sendResponseJson:@"undefined" error:NO];
}


/**
Send back a success result with a string as the response parameter.

@param response The string to be sent back as the first JavaScript parameter.
*/
- (void)sendSuccessString:(NSString *)response
{
    [self sendResponseJson:[self jsonEscape:response] error:NO];
}


/**
Send back a success result with the specified dictionary as the first JavaScript parameter.

@param response The dictionary to be conerted into JSON notation and sent back as the first JavaScript parameter.
*/
- (void)sendSuccessObject:(id)response
{
    NSString *json;
    
    if (response == nil) {
        json = @"null";
    }
    else {
        json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:response
                                                                              options:0
                                                                                error:nil]
                                     encoding:NSUTF8StringEncoding];
    }

    [self sendResponseJson:json error:NO];
}


/**
Send back an error result with no parameters.
*/
- (void)sendError
{
    [self sendResponseJson:@"undefined" error:YES];
}


/**
Send back an error result with a string as the response parameter.

@param response The string to be sent back as the first JavaScript parameter.
*/
- (void)sendErrorString:(NSString *)errorMessage
{
    [self  sendResponseJson:[self jsonEscape:errorMessage] error:YES];
}


/**
Send back an error result with the specified dictionary as the first JavaScript parameter.

@param response The dictionary to be conevrted into JSON notation and sent back as the first JavaScript parameter.
*/
- (void)sendErrorObject:(NSDictionary *)response
{
    NSString *json;
    
    if (response == nil) {
        json = @"null";
    }
    else {
        json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:response
                                                                              options:0
                                                                                error:nil]
                                     encoding:NSUTF8StringEncoding];
    }

    [self sendResponseJson:json error:YES];
}


/**
 Escape the string to make it JSON safe.
 
 @param string The string to be encoded as JSON.
 */
- (NSString *)jsonEscape:(NSString *)string
{
    NSString *json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:@[string]
                                                                                    options:0
                                                                                      error:nil]
                                           encoding:NSUTF8StringEncoding];
    
    return [json substringWithRange:NSMakeRange(1, json.length - 2)];
}

@end

