//
//  RKBLEZebraPrint.h
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 9/24/18.
//

#import <Foundation/Foundation.h>

@interface RKBLEZebraPrint : NSObject

@property (strong, nonatomic, readonly) NSString *printerName;

- (void)setPrinterName:(NSString *)printerName;
- (BOOL)print:(NSString *)zpl;

@end
