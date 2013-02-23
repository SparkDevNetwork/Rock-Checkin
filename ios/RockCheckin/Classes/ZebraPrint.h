//
//  ZebraPrint.h
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//
//

#import <Cordova/CDV.h>

#import <Foundation/Foundation.h>

@interface ZebraPrint : CDVPlugin

- (void)printTags:(CDVInvokedUrlCommand*)command;


@end
