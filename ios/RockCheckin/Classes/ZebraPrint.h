//
//  ZebraPrint.h
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//
//

#import <Foundation/Foundation.h>

@interface ZebraPrint : NSObject

/**
 Process a Javascript request to print the label tags.
 
 @param jsonString The JSON string that containts the label data.
 */
- (NSString *)printJsonTags:(NSString *)jsonString;

@end
