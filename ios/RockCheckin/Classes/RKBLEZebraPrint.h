//
//  RKBLEZebraPrint.h
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 9/24/18.
//

#import <Foundation/Foundation.h>

@interface RKBLEZebraPrint : NSObject

@property (strong, nonatomic, readonly) NSString *printerName;

/**
 Set the name of the printer and begin scanning for this device name

 @param printerName The name of the printer to be connected to
 */
- (void)setPrinterName:(NSString *)printerName;

/**
 Print the specified ZPL code to the connected printer

 @param data The ZPL data to be sent to the printer
 @return YES if the label was printed or NO if an error occurred
 */
- (BOOL)print:(NSData *)data;

@end
