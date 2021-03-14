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

/**
 Prints a single label to the printer.
 
 @param labelContent The text contents to be sent to the printer.
 @param printerAddress The printer address or name to connect to.
 @param errorMessage Contains any error message on return if method returns NO.
 @returns YES if the label was printed or NO if an error occurred.
 */
- (BOOL)printLabelContent:(NSString *)labelContent toPrinter:(NSString *)printerAddress error:(NSString **)errorMessage;

@end
