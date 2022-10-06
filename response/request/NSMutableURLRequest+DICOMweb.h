#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface NSMutableURLRequest (DICOMweb)

//completes requests with cachePolicy and timeout

//contentType and accept refer to media-type
//   contentType is of the request
//   accept is what is expected from the response

//in the case of WADOURI,
//   leave contentType empty (@"") and
//   put the value for the eventual parameter "contentType" into accept
//BOOL iswadouri=[URLString containsString:@"requestType=WADO"];


//cachePolicy 0 defaults to NSURLRequestReloadIgnoringCacheData
//https://nshipster.com/nsurlcache/
// https://learn.microsoft.com/en-us/dotnet/api/foundation.nsurlrequestcachepolicy?view=xamarin-ios-sdk-12
/*(0 is default)
 0 NSURLRequestUseProtocolCachePolicy
   If a cached response does not exist for the request, the URL loading system fetches the data from the originating source.
   Otherwise, if the cached response does not indicate that it must be revalidated every time, and if the cached response is not stale (past its expiration date), the URL loading system returns the cached response.
   If the cached response is stale or requires revalidation, the URL loading system makes a HEAD request to the originating source to see if the resource has changed. If so, the URL loading system fetches the data from the originating source. Otherwise, it returns the cached response.
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestuseprotocolcachepolicy
   UseProtocolCachePolicy
 
 1 NSURLRequestReloadIgnoringLocalCacheData
   The URL load should be loaded only from the originating source.
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestreloadignoringlocalcachedata
   ReloadIgnoringLocalCacheData

 1 NSURLRequestReloadIgnoringCacheData
   ibid 1
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestreloadignoringcachedata
   ReloadIgnoringCacheData
 
 2 NSURLRequestReturnCacheDataElseLoad
   Use existing cache data, regardless or age or expiration date, loading from originating source only if there is no cached data.
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestreturncachedataelseload
   ReturnCacheDataElseLoad
 
 3 NSURLRequestReturnCacheDataDontLoad
   If there is no existing data in the cache corresponding to a URL load request, no attempt is made to load the data from the originating source, and the load is considered to have failed. This constant specifies a behavior that is similar to an “offline” mode.
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestreturncachedatadontload
   ReturnCacheDataDoNotLoad
 
 4 NSURLRequestReloadIgnoringLocalAndRemoteCacheData
   Ignore local cache data, and instruct proxies and other intermediates to disregard their caches so far as the protocol allows.
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestreloadignoringlocalandremotecachedata
   ReloadIgnoringLocalAndRemoteCacheData
 
 5 NSURLRequestReloadRevalidatingCacheData (10.15+)
   Use cache data if the origin source can validate it; otherwise, load from the origin.
   https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy/nsurlrequestreloadrevalidatingcachedata
 ReloadRevalidatingCacheData
 */


typedef NS_ENUM(NSUInteger, HTTPRequestMethod) {
   GET = 0,
   HEAD,
   POST,
   PUT,
   DELETE,
   CONNECT,
   OPTIONS,
   TRACE,
   PATCH
};

+(NSMutableURLRequest*)retrieveMultiDICM:(NSString*)endpoint
                                 studies:(NSString*)E
                                  series:(NSString*)S
                               instances:(NSString*)I
;
// /rendered /metadata /frames /bulkdataURI


//query

//store

//worklist

//capabilities

@end

NS_ASSUME_NONNULL_END
