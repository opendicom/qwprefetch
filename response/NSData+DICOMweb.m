#import "NSData+DICOMweb.h"
#import "NSMutableURLRequest+DICOMweb.h"

@implementation NSData (DICOMweb)

static NSData *hhData=nil;
static NSData *rnData=nil;
static NSData *rnrnData=nil;

+(NSData*)syncRetrieveMultiDICMendpoint:(NSString*)U E:(NSString*)E S:(NSString*)S I:(NSString*)I resultPointers:(NSMutableDictionary*)Idict
{
   NSMutableURLRequest *request=
   [NSMutableURLRequest retrieveMultiDICM:(NSString*)U
                                  studies:(NSString*)E
                                   series:(NSString*)S
                                instances:(NSString*)I
   ];
   if (request==nil) return nil;

   NSHTTPURLResponse *response=nil;
   NSError *error=nil;
   NSData *data=[NSData dataWithSyncRequest:request returningResponse:&response error:&error];
   if (error) NSLog(@"%@",[error description]);
   if (response.statusCode!=200) return nil;
   if (!data.length) return nil;
   if (data.length < 1000) return nil;//no DICOM is so short

   //singleton searching data init
   if (!hhData) hhData=[@"--" dataUsingEncoding:NSASCIIStringEncoding];
   if (!rnData) rnData=[@"\r\n" dataUsingEncoding:NSASCIIStringEncoding];
   if (!rnrnData) rnrnData=[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];

   //parse mutable data
   NSRange dataRange=NSMakeRange(0, data.length);
   
   //initial --B\r\n
   NSRange boundaryPrefixRange=[data rangeOfData:hhData options:0 range:dataRange];
   NSRange boundarySuffixRange=[data rangeOfData:rnData options:0 range:dataRange];
   NSData *boundaryData=[data subdataWithRange:NSMakeRange(boundaryPrefixRange.location,boundarySuffixRange.location -boundaryPrefixRange.location)];
   
   //data loop
   uint16 suffix=0;
   [data getBytes:&suffix range:boundarySuffixRange];
   NSRange dicomRange=NSMakeRange(NSNotFound,0);

   char cLength;
   NSRange cLengthRange=NSMakeRange(NSNotFound,1);

   char iLength;
   char iLast;
   NSRange iLengthRange=NSMakeRange(NSNotFound,1);
   NSRange iLastRange=NSMakeRange(NSNotFound,1);
   NSRange iRange=NSMakeRange(NSNotFound,0);

   while (suffix != 0x2D2D)//--
   {
      //for each part
      
      //find dicom offset
      NSRange dicomPrefixRange=[data rangeOfData:rnrnData options:0 range:NSMakeRange(boundarySuffixRange.location,data.length-boundarySuffixRange.location)];
      
      //find next part boundary prefix
      NSRange nextBoundaryRange=[data rangeOfData:boundaryData options:0 range:NSMakeRange(boundarySuffixRange.location,data.length-boundarySuffixRange.location)];
      boundarySuffixRange.location=nextBoundaryRange.location+nextBoundaryRange.length;
      //new boundary suffix
      [data getBytes:&suffix range:boundarySuffixRange];

      //dicom
      dicomRange.location=dicomPrefixRange.location+dicomPrefixRange.length;
      dicomRange.length=data.length-nextBoundaryRange.location;
      
      //find SOP iuid
      cLengthRange.location=dicomRange.location + 0xE4;
      [data getBytes:&cLength range:cLengthRange];
      iLengthRange.location=cLengthRange.location+0x02+cLength+0x06;
      [data getBytes:&iLength range:iLengthRange];
      
      iLastRange.location=iLengthRange.location+0x02+iLength-0x01;
      [data getBytes:&iLast range:iLastRange];

      iRange.location=iLengthRange.location+0x02;
      iRange.length=iLength-(iLast == 0x00);
      NSData *iData=[data subdataWithRange:iRange];
      NSString *I=[[NSString alloc]initWithData:iData encoding:NSASCIIStringEncoding];

      [Idict setValue:[NSValue valueWithRange:iRange] forKey:I];
   }
   return data;
}


+ (NSData *)dataWithSyncRequest:(NSURLRequest *)request returningResponse:(NSURLResponse *__autoreleasing *)responsePointer error:(NSError *__autoreleasing *)errorPointer
{
    dispatch_semaphore_t semaphore;
    __block NSData *result = nil;
    
    semaphore = dispatch_semaphore_create(0);
    
    void (^completionHandler)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error);
    completionHandler = ^(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error)
    {
        if ( errorPointer != NULL )
        {
            *errorPointer = error;
        }
        
        if ( responsePointer != NULL )
        {
            *responsePointer = response;
        }
        
        if ( error == nil )
        {
           result = data;
        }
        
        dispatch_semaphore_signal(semaphore);
    };
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return result;
}

@end
