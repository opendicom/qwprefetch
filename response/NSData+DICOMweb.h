#import <Foundation/Foundation.h>

@interface NSData (DICOMweb)

+(NSData*)syncRetrieveMultiDICMendpoint:(NSString*)U E:(NSString*)E S:(NSString*)S I:(NSString*)I resultPointers:(NSMutableDictionary*)Is;

+ (NSData *)dataWithSyncRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error;

@end
