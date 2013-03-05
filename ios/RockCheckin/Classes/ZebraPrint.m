//
//  ZebraPrint.m
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//
//

#import "ZebraPrint.h"
#import <Cordova/CDV.h>

#import "TcpPrinterConnection.h"
#import "ZebraPrinterConnection.h"
#import "SBJson.h"
#import "EGOCache.h"


@implementation ZebraPrint

- (void)printTags:(CDVInvokedUrlCommand *)command
{
    // TODO consider putting this on a separate tread (see Cordova docs)
    NSLog(@"[LOG] ZebraPrint Plugin Called");
    
    CDVPluginResult* pluginResult = nil;
    NSString* jsonString = [command.arguments objectAtIndex:0];
    
    // if no json data sent return error
    if (jsonString == nil || [jsonString length] == 0) {
        NSLog(@"[ERROR] No label data sent to print");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsArray:[NSArray arrayWithObjects:@"No label data sent to print", @"false", nil]];
    } else {
        // we have something, let's parse the json
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        
        NSArray *labels = [parser objectWithString:jsonString];

        if (labels == nil || [labels count] == 0) {
            // json was not able to be parsed
            NSLog(@"[ERROR] JSON was not able to be parsed: %@", parser.error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsArray:[NSArray arrayWithObjects:[NSString stringWithFormat:@"An error occurred: %@", parser.error], @"false", nil]];
            
        } else {
            // we have parsed successfully
            NSLog(@"[LOG] ZebraPrint plugin has parsed %d labels", [labels count]);
            
            // create reusable printer connection
            id<ZebraPrinterConnection, NSObject> printerConn = nil;
            
            // iterate through labels
            for (id label in labels) {
                
                NSString *printerIP = [label objectForKey:@"PrinterAddress"];
                NSString *labelFile = [label objectForKey:@"LabelFile"];
                NSString *labelKey = [label objectForKey:@"LabelKey"];
                
                NSDictionary *mergeFields = [label objectForKey:@"MergeFields"];
                
                // get label contents
                NSString *labelContents = [self getLabelContents:labelKey labelLocation:labelFile];
                
                // create connection to the printer
                printerConn = [[TcpPrinterConnection alloc] initWithAddress:printerIP andWithPort:9100];
                
                BOOL success = [printerConn open];
                
                NSString *zplData = @"^XA^FO20,20^A0N,25,25^FDThis is a ZPL test.^FS^XZ";
                
                NSError *error = nil;
                // Send the data to printer as a byte array.
                success = success && [printerConn write:[zplData dataUsingEncoding:NSUTF8StringEncoding] error:&error];
                
                if (success != YES || error != nil) {
                    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                    [errorAlert show];
                    [errorAlert release];
                }
                
                // Close the connection to release resources.
                [printerConn close];
                [printerConn release];
                
                
                //file:///Users/jedmiston/Applications/zebralink_sdk/iOS/v1.0.214/doc/html/index.html

                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                
            }
        }
        
        [parser release], parser = nil;
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    
}

- (NSString*)getLabelContents:(NSString*)labelKey labelLocation:(NSString*)labelFile
{
    // get label contents from cache
    NSString *labelContents = [[EGOCache currentCache] dataForKey:labelKey];
    
    // check if label was found in cache
    if ([labelContents length] == 0) {
        NSLog(@"Label was not found in cache!");
    }
    
    return nil;
}


@end
