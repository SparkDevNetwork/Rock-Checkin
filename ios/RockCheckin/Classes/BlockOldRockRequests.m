//
//  BlockOldRockRequests.m
//  RockCheckin
//
//  Created by Daniel Hazelbaker on 2/24/17.
//
//

#import "BlockOldRockRequests.h"

@implementation BlockOldRockRequests


/**
 Enable this class in the NSURLProtocol system.
 */
+ (void)enable
{
    [NSURLProtocol registerClass:[BlockOldRockRequests class]];
}



/**
 Determines if the NSURLRequest is one that we should handle ourselves.

 @param request The request that is about to be initiated.
 @return YES if this request should be handled by an instance of our class.
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSURL *url = request.URL;
    
    //
    // URLs from the local filesystem are okay.
    //
    if ([url.scheme caseInsensitiveCompare:@"file"] != NSOrderedSame)
    {
        NSString *filename = url.lastPathComponent;
        
        if ([filename caseInsensitiveCompare:@"cordova-2.4.0.js"] == NSOrderedSame)
        {
            return YES;
        }
        
        if ([filename caseInsensitiveCompare:@"ZebraPrint.js"] == NSOrderedSame)
        {
            return YES;
        }
    }
    
    return NO;
}



/**
 This method must exist in all NSURLProtocol implementations.

 @param request The incoming request
 @return Same as incoming to indicate no change
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}


/**
 Determine if the request is equivalent to the cached request.

 @param a Request A to compare
 @param b Request B to compare
 @return YES if the requests are the same and the cached value can be used
 */
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}


/**
 When we start loading immedietly fail so the request is not actually loaded.
 */
- (void)startLoading
{
    [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{}]];
}


/**
 Request to stop the load. Ignored.
 */
- (void)stopLoading
{
}


@end
