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
//  CameraViewController.h
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 1/18/20.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CameraViewControllerDelegate;

@interface CameraViewController : UIViewController

@property (weak, nonatomic) id<CameraViewControllerDelegate> delegate;

/**
 Start the camera and begin watching for any barcodes.
 */
- (void)start;

/**
 Stop the camera and cease watching for barcodes.
 */
- (void)stop;

@end

@protocol CameraViewControllerDelegate

/**
 Called when the camera view has detected a generic barcode.

 @param controller The camera view controller that scanned the barcode.
 @param code The code that was scanned.
*/
- (void)cameraViewController:(CameraViewController *)controller didScanGenericCode:(NSString *)code;

/**
 Called when the camera view wants to cancel itself.
 
 @param controller The camera view controller that should be cancelled.
 */
- (void)cameraViewControllerDidCancel:(CameraViewController *)controller;

/**
 Called when a pre-check-in code has been scanned and must be processed.
 
 @param controller The camera view controller that scanned the barcode.
 @param code The code that was scanned.
 @param callback The completion callback that must be called when printing has finished.
 */
- (void)cameraViewController:(CameraViewController *)controller didScanPreCheckInCode:(NSString *)code completedCallback:(void (^)(NSString *))callback;

@end

NS_ASSUME_NONNULL_END
