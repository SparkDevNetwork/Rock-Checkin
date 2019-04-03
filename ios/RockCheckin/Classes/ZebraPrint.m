//
//  ZebraPrint.m
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//
//

#import "ZebraPrint.h"
#import "RKBLEZebraPrint.h"
#import <Cordova/CDV.h>
#import "FastSocket.h"

#import "SBJson.h"
#import "EGOCache.h"
#import "AppDelegate.h"


@implementation ZebraPrint

- (void)printTags:(CDVInvokedUrlCommand *)command
{
    BOOL labelErrorOccurred = NO;
    
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
            NSLog(@"[LOG] ZebraPrint plugin has parsed %lu labels", (unsigned long)[labels count]);
            
            NSMutableArray *failedPrinters = [[NSMutableArray alloc] init];
            
            // iterate through labels
            for (id label in labels) {
                
                NSString *printerAddress = [label objectForKey:@"PrinterAddress"];
                NSString *labelFile = [label objectForKey:@"LabelFile"];
                NSString *labelKey = [label objectForKey:@"LabelKey"];
                
                NSDictionary *mergeFields = [label objectForKey:@"MergeFields"];
                
                // change printer ip if printer overide setting is present
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                NSString *overridePrinter = [defaults stringForKey:@"printer_override"];
                
                if (overridePrinter != nil && overridePrinter.length > 0) {
                    printerAddress = overridePrinter;
                }
                
                // If we already failed to connect to this printer, don't waste time.
                if ([failedPrinters containsObject:printerAddress]) {
                    continue;
                }

                NSString *printerIP, *printerPort;
                
                // If the user specified in 0.0.0.0:1234 syntax then pull out the IP and port numbers.
                if ([printerAddress containsString:@":"])
                {
                    NSArray *segments = [printerAddress componentsSeparatedByString:@":"];
                    
                    printerIP = segments[0];
                    printerPort = segments[1];
                }
                else
                {
                    printerIP = printerAddress;
                    printerPort = @"9100";
                }
                
                // get label contents
                NSString *labelContents = [self getLabelContents:labelKey labelLocation:labelFile];
                
                if (labelContents != nil) {
                    // merge label
                    NSString *mergedLabel = [self mergeLabelFields:labelContents mergeFields:mergeFields];

                    if ([NSUserDefaults.standardUserDefaults boolForKey:@"bluetooth_printing"])
                    {
                        RKBLEZebraPrint *printer = ((AppDelegate *)UIApplication.sharedApplication.delegate).blePrinter;
                        BOOL success = [printer print:mergedLabel];
                        if (!success) {
                            NSLog(@"[ERROR] Unable to print to bluetooth printer.");
                        }
                    }
                    else
                    {
                        FastSocket *printerConn = [[FastSocket alloc] initWithHost:printerIP andPort:printerPort];
                        
                        BOOL success = [printerConn connect:2];
                        const char *bytes = [mergedLabel UTF8String];
                        long len = strlen(bytes);

                        success = success && [printerConn sendBytes:bytes count:len] == len;
                        
                        if (success != YES) {
                            NSLog(@"[ERROR] Unable to print to printer: %@", printerIP);
                            [failedPrinters addObject:printerAddress];
                        }
                        
                        // Close the connection to release resources.
                        [printerConn close];
                    }

                } else {
                    labelErrorOccurred = YES;
                }
            }
        }
        
        parser = nil;
    }

    if (labelErrorOccurred) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsArray:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Unable to retrieve labels from server."], @"false", nil]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString*)getLabelContents:(NSString*)labelKey labelLocation:(NSString*)labelFile
{
    // determine cache preference
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL usecache = [defaults boolForKey:@"enable_caching"];
    
    NSString *labelContents = nil;
    
    if (usecache) {
        labelContents = [[EGOCache globalCache] stringForKey:labelKey];
    } else {
        // destroy the cache if it exists
        [[EGOCache globalCache] clearCache];
    }
    
    // check if label was found in cache
    if ([labelContents length] != 0) {
        NSLog(@"[LOG] Label was found in cache.");
        return labelContents;
    } else {
        NSLog(@"[LOG] Label was not found in cache. Retrieving it from server.");
        
        // get label from server
        @try {
            NSURL *url = [NSURL URLWithString:labelFile];
            NSError* error = nil;
            NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];

            // check if error ocurred
            if (error) {
                NSLog(@"[ERROR] Could not retrieve label from server: %@", error);
                return nil;
            }
            
            // store label file in cache
            if (usecache) {
            
                NSString *cacheDuration = [defaults stringForKey:@"cache_duration"];
                NSScanner *scanner = [NSScanner scannerWithString:cacheDuration ];
                
                double doubleCacheDuration;
                
                if ([scanner scanDouble:&doubleCacheDuration]) {
                    doubleCacheDuration = doubleCacheDuration * 60; // convert mins to seconds
                } else {
                    doubleCacheDuration = 60 * 60 * 24; // default to 1 day
                }
                
                [[EGOCache globalCache] setString:content forKey:labelKey withTimeoutInterval:doubleCacheDuration];
            } 
            return content;
        }
        @catch (NSException * e) {
            NSLog(@"Exception: %@", e);
            return nil;
        }
    }
    
    return nil;
}

- (NSString*)mergeLabelFields:(NSString*)labelContents mergeFields:(NSDictionary*)mergeFields {
    
    NSMutableString *mergedLabel = [NSMutableString stringWithCapacity:0];
    [mergedLabel setString:labelContents];
    
    for(id key in mergeFields) {
        
        NSString *value = [mergeFields objectForKey:key];
        
        if ([value length] > 0) {
            // merge the contents of the field
            NSString *mergePattern = [NSString stringWithFormat:@"(?<=\\^FD)(%@)(?=\\^FS)",key];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:mergePattern options:0 error:nil];
            
            [regex replaceMatchesInString:mergedLabel options:0 range:NSMakeRange(0, [mergedLabel length]) withTemplate:[value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]];
            
        } else {
            // remove the field origin (used for inverting backgrounds)
            NSString *fieldOriginPattern = [NSString stringWithFormat:@"\\^FO.*\\^FS\\s*(?=\\^FT.*\\^FD%@\\^FS)",key];
            NSRegularExpression *fieldOriginRegex = [NSRegularExpression regularExpressionWithPattern:fieldOriginPattern options:0 error:nil];
            
            [fieldOriginRegex replaceMatchesInString:mergedLabel options:0 range:NSMakeRange(0, [mergedLabel length]) withTemplate:@""];
            
            // remove the field data (the actual value)
            NSString *fieldDataPattern = [NSString stringWithFormat:@"\\^FD%@\\^FS",key];
            NSRegularExpression *fieldDataRegex = [NSRegularExpression regularExpressionWithPattern:fieldDataPattern options:0 error:nil];
            
            [fieldDataRegex replaceMatchesInString:mergedLabel options:0 range:NSMakeRange(0, [mergedLabel length]) withTemplate:@"^FD^FS"];
        }
    }

    return mergedLabel;
}


@end
