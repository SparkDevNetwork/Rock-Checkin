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
//  RKNativeJSBridge.h
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 1/19/20.
//

#import "MainViewController.h"
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RKNativeJSBridge : NSObject

/**
 Initialize a new RKNativeJSBridge object that will be owned by the main view controller.
 
 @param controller The MainViewController to pass messages along to.
 */
- (id)initWithMainController:(MainViewController *)controller;

@end

NS_ASSUME_NONNULL_END
