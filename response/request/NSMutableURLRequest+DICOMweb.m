#import "NSMutableURLRequest+DICOMweb.h"

@implementation NSMutableURLRequest (DICOMweb)


NSTimeInterval const defaultTimeout=10;
//NSTimeInterval timeoutinterval;//doubleValue
static NSData *emptyData;
static NSString *emptyString;
+(void)initialize {
   emptyData=[NSData data];
   emptyString=[NSString string];
}



+(NSMutableURLRequest*)retrieveMultiDICM:(NSString*)endpoint
                                 studies:(NSString*)E
                                  series:(NSString*)S
                               instances:(NSString*)I
{
   
   if (!E) return nil;
   if (I && !S) return nil;
   NSString *string=nil;
   if (!S) string=[NSString stringWithFormat:@"%@/studies/%@",endpoint,E];
   else if (!I) string=[NSString stringWithFormat:@"%@/studies/%@/series/%@",endpoint,E,S];
   else  string=[NSString stringWithFormat:@"%@/studies/%@/series/%@/instances/%@",endpoint,E,S,I];
      
   NSMutableURLRequest *request =
   [NSMutableURLRequest requestWithURL:[NSURL URLWithString:string]
                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                       timeoutInterval:defaultTimeout
   ];
   [request setHTTPMethod:@"GET"];
   [request setValue:@"multipart/related; type=application/dicom" forHTTPHeaderField:@"accept"];
   
   return request;
}

@end
