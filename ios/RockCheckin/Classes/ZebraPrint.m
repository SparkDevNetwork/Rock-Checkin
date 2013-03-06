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
                
                // merge label
                NSString *mergedLabel = [self mergeLabelFields:labelContents mergeFields:mergeFields];
                
                // create connection to the printer
                printerConn = [[TcpPrinterConnection alloc] initWithAddress:printerIP andWithPort:9100];
                
                BOOL success = [printerConn open];
                
                //NSString *zplData = @"^XA^FO20,20^A0N,25,25^FDThis is a ZPL test.^FS^XZ";
                
                NSError *error = nil;
                // Send the data to printer as a byte array.
                success = success && [printerConn write:[mergedLabel dataUsingEncoding:NSUTF8StringEncoding] error:&error];
                
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
    NSString *labelContents = [[EGOCache currentCache] stringForKey:labelKey];
    
    // check if label was found in cache
    if ([labelContents length] != 0) {
        NSLog(@"[LOG] Label was found in cache.");
        return labelContents;
    } else {
        NSLog(@"[LOG] Label was not found in cache. Retrieving it from server.");
        
        // get label from server
        NSURL *url = [NSURL URLWithString:labelFile];
        NSError* error;
        NSString *content = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];

        // check if error ocurred
        if (error != nil) {
            NSLog(@"[ERROR] Could not retrieve label from server: %@", error);
            return nil;
        }
        
        // store label file in cache
        [[EGOCache currentCache] setString:content forKey:labelKey withTimeoutInterval:60 * 60 * 24];
        
        return content;
    }
    
    return nil;
}

- (NSString*)mergeLabelFields:(NSString*)labelContents mergeFields:(NSDictionary*)mergeFields {
    
    bool labelProcessing = YES;
    NSRange rangeToSearchWithin = NSMakeRange(0, labelContents.length);
    NSMutableString *mergedLabel = [NSMutableString stringWithCapacity:0];
    NSRange endTagRange =  NSMakeRange(0,0);
    
    while(labelProcessing) {
        NSRange searchResult = [labelContents rangeOfString:@"^FN" options:NSCaseInsensitiveSearch range: rangeToSearchWithin];
        
        if(searchResult.location == NSNotFound) {
            labelProcessing = NO;
        } else {
            // get the field number
            NSRange endTagSearchRange = NSMakeRange(searchResult.location, labelContents.length - searchResult.location);
            NSRange endFieldNumRange = [labelContents rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:endTagSearchRange];
            
            NSString *fieldNumber = [labelContents substringWithRange:NSMakeRange(searchResult.location + searchResult.length, endFieldNumRange.location - (searchResult.location + searchResult.length))];
            
            // get the end location of the field
            endTagRange = [labelContents rangeOfString:@"^FS" options:NSCaseInsensitiveSearch range:endTagSearchRange];
            
            // add label part to merged label
            [mergedLabel appendString:[labelContents substringWithRange:NSMakeRange(rangeToSearchWithin.location, searchResult.location - rangeToSearchWithin.location)]];
            NSString *mergeField = [mergeFields objectForKey:fieldNumber];
            
            // if data for the merge field was not sent print blank instead of null
            if (mergeField == nil) {
                mergeField = [NSString stringWithFormat:@""];
            }
            
            [mergedLabel appendString:[NSString stringWithFormat:@"^FD%@^FS", mergeField]];
            
            // increment our search range
            int newLocationToStartAt = endTagRange.location + endTagRange.length;
            rangeToSearchWithin = NSMakeRange(newLocationToStartAt, labelContents.length - newLocationToStartAt);
        }  
    }
    
    // add final part of the label
    [mergedLabel appendString:[labelContents substringWithRange:NSMakeRange(endTagRange.location + endTagRange.length, labelContents.length - (endTagRange.location + endTagRange.length) )]];
    
    return mergedLabel;
}


@end
