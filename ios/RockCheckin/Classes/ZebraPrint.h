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

/**
 Process a Javascript request to print the label tags.
 
 @param jsonString The JSON string that containts the label data.
 */
- (NSString *)printJsonTags:(NSString *)jsonString;

/**
 Process a Javascript request to print the label tags.

 @param command The object that contains all the parameters about the command
 */
- (void)printTags:(CDVInvokedUrlCommand *)command;

@end
