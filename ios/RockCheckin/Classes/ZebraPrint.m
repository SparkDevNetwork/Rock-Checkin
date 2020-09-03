//
//  ZebraPrint.m
//  RockCheckin
//
//  Created by Jon Edmiston on 2/21/13.
//
//

#import "ZebraPrint.h"
#import "RKBLEZebraPrint.h"
#import "FastSocket.h"

#import "SBJson.h"
#import "EGOCache.h"
#import "AppDelegate.h"


@implementation ZebraPrint

/**
Process a Javascript request to print the label tags.

@param jsonString The JSON string that containts the label data.
*/
- (NSString *)printJsonTags:(NSString *)jsonString
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL labelErrorOccurred = NO;
    BOOL enableLabelCutting = [defaults boolForKey:@"enable_label_cutting"];
    NSString *errorMessage = nil;
    
    NSLog(@"[LOG] ZebraPrint Plugin Called");
    
    // if no json data sent return error
    if (jsonString == nil || [jsonString length] == 0) {
        NSLog(@"[ERROR] No label data sent to print");
        errorMessage = @"No label data sent to print";
    } else {
        // we have something, let's parse the json
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        
        NSArray *labels = [parser objectWithString:jsonString];

        if (labels == nil || [labels count] == 0) {
            // json was not able to be parsed
            NSLog(@"[ERROR] JSON was not able to be parsed: %@", parser.error);
            errorMessage = [NSString stringWithFormat:@"An error occurred: %@", parser.error];
            
        } else {
            // we have parsed successfully
            NSLog(@"[LOG] ZebraPrint plugin has parsed %lu labels", (unsigned long)[labels count]);
            
            NSMutableArray *failedPrinters = [[NSMutableArray alloc] init];
            NSDictionary *groupedLabels = [self groupLabelsByPrinter:labels];
            
            for (NSString *key in groupedLabels.allKeys) {
                // iterate through labels
                NSArray *printerLabels = [groupedLabels objectForKey:key];
                int labelIndex = 0;
                
                for (id label in printerLabels) {
                    NSString *printerAddress = key;
                    int printerTimeout = 2;
                    NSString *labelFile = [label objectForKey:@"LabelFile"];
                    NSString *labelKey = [label objectForKey:@"LabelKey"];
                    NSDictionary *mergeFields = [label objectForKey:@"MergeFields"];
                    
                    labelIndex += 1;
                    
                    // change printer ip if printer overide setting is present
                    NSString *overridePrinter = [defaults stringForKey:@"printer_override"];
                    
                    if (overridePrinter != nil && overridePrinter.length > 0) {
                        printerAddress = overridePrinter;
                    }
                    
                    // Set printer timeout value
                    NSString *printerTimeoutString = [defaults stringForKey:@"printer_timeout"];
                    
                    if (printerTimeoutString != nil && printerTimeoutString.intValue > 0) {
                        printerTimeout = printerTimeoutString.intValue;
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
                        
                        mergedLabel = [self trimTrailing:mergedLabel];
                        
                        //
                        // Is cutter attached, and is this the last label or a
                        // "Rock Cut" command?
                        //
                        if (enableLabelCutting && (labelIndex == printerLabels.count || [mergedLabel rangeOfString:@"ROCK_CUT"].location != NSNotFound)) {
                            //
                            // Override any tear mode commandd (^MMT) by injecting
                            // the  cut mode (^MMC) command.
                            //
                            mergedLabel = [self replaceIn:mergedLabel
                                               ifEndsWith:@"^XZ"
                                               withString:@"^MMC^XZ"];
                        }
                        else if (enableLabelCutting) {
                            //
                            // Inject the supress back-feed (^XB).
                            //
                            mergedLabel = [self replaceIn:mergedLabel
                                               ifEndsWith:@"^XZ"
                                               withString:@"^XB^XZ"];
                        }
                        
                        NSLog(@"Printing label: %@", mergedLabel);
                        if ([NSUserDefaults.standardUserDefaults boolForKey:@"bluetooth_printing"])
                        {
                            RKBLEZebraPrint *printer = AppDelegate.sharedDelegate.blePrinter;
                            BOOL success = [printer print:mergedLabel];
                            if (!success) {
                                errorMessage = @"Unable to print to printer.";
                                NSLog(@"[ERROR] Unable to print to bluetooth printer.");
                            }
                        }
                        else
                        {
                            FastSocket *printerConn = [[FastSocket alloc] initWithHost:printerIP andPort:printerPort];
                            
                            BOOL success = [printerConn connect:printerTimeout];
                            const char *bytes = [mergedLabel UTF8String];
                            long len = strlen(bytes);
                            
                            success = success && [printerConn sendBytes:bytes count:len] == len;
                            
                            if (success != YES) {
                                errorMessage = @"Unable to print to printer.";
                                NSLog(@"[ERROR] Unable to print to printer: %@", printerIP);
                                [failedPrinters addObject:printerAddress];
                            }
                            
                            // Close the connection to release resources.
                            [printerConn close];
                        }
                    }
                    else {
                        labelErrorOccurred = YES;
                    }
                }
            }
        }
        
        parser = nil;
    }

    if (errorMessage == nil && labelErrorOccurred) {
        errorMessage = @"Unable to retrieve labels from server.";
    }

    return errorMessage;
}


/**
 Groups the labels by the printer address.
 
 @param labels The collection of labels to be grouped.
 */
- (NSDictionary *)groupLabelsByPrinter:(NSArray *)labels
{
    NSMutableDictionary *groupedLabels = [NSMutableDictionary new];
    
    for (id label in labels) {
        NSString *printerAddress = [label objectForKey:@"PrinterAddress"];

        if ([groupedLabels objectForKey:printerAddress] == nil) {
            [groupedLabels setObject:[NSMutableArray new] forKey:printerAddress];
        }
        
        [[groupedLabels objectForKey:printerAddress] addObject:label];
    }
    
    return groupedLabels;
}


/**
 Removes any trailing whitespace characters from the string.
 
 @param string The string to be trimmed.
 */
- (NSString *)trimTrailing:(NSString *)string
{
    NSCharacterSet *characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSRange rangeOfLastWantedCharacter = [string rangeOfCharacterFromSet:[characterSet invertedSet]
                                                                 options:NSBackwardsSearch];
    
    if (rangeOfLastWantedCharacter.location == NSNotFound) {
        return @"";
    }
    
    return [string substringToIndex:rangeOfLastWantedCharacter.location + 1];
}


/**
 Replace the tail end of the string with a new value if it matches the
 specified tail string.
 
 @param string  The string to be searched.
 @param endsWith The needle to search for in the haystack.
 @param replacement The string to replace the needle with if it was found.
 */
- (NSString *)replaceIn:(NSString *)string ifEndsWith:(NSString *)endsWith withString:(NSString *)replacement
{
    if ([string hasSuffix:endsWith]) {
        NSString *tmp = [string substringToIndex:string.length - endsWith.length];
        
        return [tmp stringByAppendingString:replacement];
    }
    
    return string;
}


/**
 Get the label contents from either cache or the remote server.
 
 @param labelKey The key to use for caching purposes.
 @param labelFile The URL that the contents should be downloaded from.
 */
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


/**
 Merge the label contents and the dynamic fields that were provided by the server.
 
 @param labelContents The contents of the unmerged label.
 @param mergeFields The fields that should be merged in.
 */
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
