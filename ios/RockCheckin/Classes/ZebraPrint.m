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
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No label data sent to print"];
    } else {
        // we have something, let's parse the json
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        
        id labelData = [parser objectWithString:jsonString];
        
        if (labelData) {
            // we have parsed successfully
            
        } else {
            // json was not able to be parsed
            NSLog(@"[ERROR] JSON was not able to be parsed: %@", parser.error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"An error occurred: %@", parser.error]];
        }
    }
    
    /*if (jsonString != nil && [jsonString length] > 0) {
        
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No label data sent to print"];
    }*/
    
    
    // create connection to the printer
    id<ZebraPrinterConnection, NSObject> thePrinterConn = [[TcpPrinterConnection alloc] initWithAddress:@"10.1.20.111" andWithPort:9100];

    //file:///Users/jedmiston/Applications/zebralink_sdk/iOS/v1.0.214/doc/html/index.html
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


@end
