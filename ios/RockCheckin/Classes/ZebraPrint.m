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
#import "SettingsHelper.h"


@implementation ZebraPrint

/**
Process a Javascript request to print the label tags.

@param jsonString The JSON string that containts the label data.
*/
- (NSString *)printJsonTags:(NSString *)jsonString
{
    BOOL labelErrorOccurred = NO;
    BOOL enableLabelCutting = [SettingsHelper boolForKey:@"enable_label_cutting"];
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
                    NSString *labelFile = [label objectForKey:@"LabelFile"];
                    NSString *labelKey = [label objectForKey:@"LabelKey"];
                    NSDictionary *mergeFields = [label objectForKey:@"MergeFields"];
                    
                    labelIndex += 1;
                    
                    // change printer ip if printer overide setting is present
                    NSString *overridePrinter = [SettingsHelper stringForKey:@"printer_override"];
                    
                    if (overridePrinter != nil && overridePrinter.length > 0) {
                        printerAddress = overridePrinter;
                    }
                    
                    // If we already failed to connect to this printer, don't waste time.
                    if ([failedPrinters containsObject:printerAddress]) {
                        continue;
                    }
                    
                    // get label contents
                    NSString *labelContents = [self getLabelContents:labelKey labelLocation:labelFile];
                    
                    if (labelContents != nil) {
                        // merge label
                        NSString *mergedLabel = [self mergeLabelFields:labelContents mergeFields:mergeFields];
                        
                        mergedLabel = [self trimTrailing:mergedLabel];
                        
                        //
                        // If the "enable label cutting" feature is enabled, then we are going to
                        // control which mode the printer is in. In this case, we will remove any
                        // tear-mode (^MMT) commands from the content and add the cut-mode (^MMC).
                        //
                        if (enableLabelCutting)
                        {
                            mergedLabel = [self amendLabelDataWithCutCommands:mergedLabel
                                                                    lastLabel:labelIndex == printerLabels.count];
                        }
                        
                        NSString *printError = nil;
                        NSData *labelData = [mergedLabel dataUsingEncoding:NSUTF8StringEncoding];
                        if (![self printLabelContent:labelData toPrinter:printerAddress error:&printError])
                        {
                            errorMessage = printError;
                            labelErrorOccurred = YES;
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
 Modifies the labelData string and returns a new string after any cut commands have
 been set.
 
 @param labelData The UTF-8 string that contains the ZPL data to print.
 @param lastLabel Should be true to indicate that this is the last label in the set.
 */
- (NSString *)amendLabelDataWithCutCommands:(NSString *)labelData lastLabel:(BOOL)lastLabel
{
    labelData = [labelData stringByReplacingOccurrencesOfString:@"^MMT"
                                                     withString:@""];
    
    //
    // Here we are forcing the printer into cut mode (because
    // we don't know if it has been put into cut-mode already) even
    // though we might be suppressing the cut below. This is correct.
    //
    labelData = [self replaceIn:labelData
                     ifEndsWith:@"^XZ"
                     withString:@"^MMC^XZ"];
    
    //
    // If it's not the last label or a "ROCK_CUT" label, then
    // we inject a supress back-feed (^XB) command which will supress the cut.
    //
    if (!(lastLabel || [labelData rangeOfString:@"ROCK_CUT"].location != NSNotFound))
    {
        labelData = [self replaceIn:labelData
                         ifEndsWith:@"^XZ"
                         withString:@"^XB^XZ"];
    }

    return labelData;
}


/**
 Prints a set of labels from v2 check-in.
 
 @param jsonString The JSON string that was received from the v2 kiosk JavaScript.
 */
- (NSArray *)printLabels:(NSString *)jsonString
{
    BOOL enableLabelCutting = [SettingsHelper boolForKey:@"enable_label_cutting"];
    int labelIndex = 0;

    NSLog(@"[LOG] ZebraPrint Plugin Called");
    
    // if no json data sent return error
    if (jsonString == nil || [jsonString length] == 0) {
        NSLog(@"[ERROR] No label data sent to print");
        return @[@"No label data sent to print"];
    }

    // we have something, let's parse the json
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    NSArray *labels = [parser objectWithString:jsonString];
    parser = nil;

    if (labels == nil || [labels count] == 0) {
        // json was not able to be parsed
        NSLog(@"[ERROR] JSON was not able to be parsed: %@", parser.error);
        return @[[NSString stringWithFormat:@"An error occurred: %@", parser.error]];
    }

    // we have parsed successfully
    NSLog(@"[LOG] ZebraPrint plugin has parsed %lu labels", (unsigned long)[labels count]);
    
    NSMutableArray *failedPrinters = [[NSMutableArray alloc] init];
    NSMutableArray *errorMessages = [[NSMutableArray alloc] init];
    
    for (id label in labels) {
        labelIndex++;
        
        NSString *printerAddress = [SettingsHelper stringForKey:@"printer_override"];
        
        if (printerAddress == nil || printerAddress.length == 0) {
            printerAddress = [label objectForKey:@"PrinterAddress"];
            
            if ([printerAddress isKindOfClass:NSNull.class]) {
                printerAddress = nil;
            }
            
            if (printerAddress == nil) {
                printerAddress = [label objectForKey:@"printerAddress"];

                if ([printerAddress isKindOfClass:NSNull.class]) {
                    printerAddress = nil;
                }
            }
        }
        
        if (printerAddress == nil || printerAddress.length == 0) {
            continue;
        }

        NSString *labelContent = [label objectForKey:@"Data"];
        NSData *labelData = NSData.data;
        
        if (labelContent == nil) {
            labelContent = [label objectForKey:@"data"];
        }
        
        if (labelContent != nil && labelContent.length != 0) {
            labelData = [[NSData alloc] initWithBase64EncodedString:labelContent options:0];
        }
        
        // If we already failed to connect to this printer, don't waste time.
        if ([failedPrinters containsObject:printerAddress]) {
            continue;
        }
        
        if (enableLabelCutting) {
            NSString *labelText = [[NSString alloc] initWithData:labelData encoding:NSUTF8StringEncoding];
            
            labelText = [self trimTrailing:labelText];
            labelText = [self amendLabelDataWithCutCommands:labelText
                                                  lastLabel:labelIndex == labels.count];
            
            labelData = [labelText dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        NSString *printError = nil;
        if (![self printLabelContent:labelData toPrinter:printerAddress error:&printError])
        {
            [failedPrinters addObject:printerAddress];
            [errorMessages addObject:printError];
        }
    }
    
    return errorMessages;
}


/**
 Prints a single label to the printer.
 
 @param labelContent The data contents to be sent to the printer.
 @param printerAddress The printer address or name to connect to.
 @param errorMessage Contains any error message on return if method returns NO.
 @returns YES if the label was printed or NO if an error occurred.
 */
- (BOOL)printLabelContent:(NSData *)labelContent toPrinter:(NSString *)printerAddress error:(NSString **)errorMessage
{
    NSString *printerIP, *printerPort;
    
    // Set printer timeout value
    int printerTimeout = 2;
    NSString *printerTimeoutString = [SettingsHelper stringForKey:@"printer_timeout"];
    
    if (printerTimeoutString != nil && printerTimeoutString.intValue > 0) {
        printerTimeout = printerTimeoutString.intValue;
    }
    
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
    
    if ([SettingsHelper boolForKey:@"bluetooth_printing"])
    {
        RKBLEZebraPrint *printer = AppDelegate.sharedDelegate.blePrinter;
        BOOL success = [printer print:labelContent];
        if (!success) {
            if (errorMessage != nil) {
                *errorMessage = @"Unable to print to printer.";
            }
            NSLog(@"[ERROR] Unable to print to bluetooth printer.");
            
            return false;
        }
    }
    else
    {
        FastSocket *printerConn = [[FastSocket alloc] initWithHost:printerIP andPort:printerPort];
            
        BOOL success = [printerConn connect:printerTimeout];
        const void *bytes = labelContent.bytes;
        long len = labelContent.length;
            
        success = success && [printerConn sendBytes:bytes count:len] == len;
            
        if (success != YES) {
            if (errorMessage != nil) {
                *errorMessage = @"Unable to print to printer.";
            }
            NSLog(@"[ERROR] Unable to print to printer: %@", printerIP);
            
            return false;
        }
            
        // Close the connection to release resources.
        [printerConn close];
    }
    
    if (errorMessage != nil) {
        *errorMessage = nil;
    }
    
    return true;
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
    BOOL usecache = [SettingsHelper boolForKey:@"enable_caching"];
    
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
            
                NSString *cacheDuration = [SettingsHelper stringForKey:@"cache_duration"];
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
