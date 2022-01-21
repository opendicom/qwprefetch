//  Created by jacquesfauquex@opendicom.com on 2014-07-30.
//  Copyright (c) 2022 opendicom.com. All rights reserved.

#import <Foundation/Foundation.h>
#import "ZZArchiveEntry.h"
#import "ZZArchive.h"
#import "ZZConstants.h"
#import "ZZChannel.h"
#import "ZZError.h"

int main(int argc, const char * argv[])
{
 @autoreleasepool {
     
    NSError *error=nil;

     
#pragma mark init
     

    NSFileManager *fileManager=[NSFileManager defaultManager];

    //http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    NSDateFormatter *DAFormatter = [[NSDateFormatter alloc] init];
    [DAFormatter setDateFormat:@"yyyyMMdd"];
    NSString *DA=[DAFormatter stringFromDate:[NSDate date]];

    //NSDateFormatter *DTFormatter = [[NSDateFormatter alloc] init];
    //[DTFormatter setDateFormat:@"yyyyMMddhhmmss"];

#pragma mark args
     
     NSMutableArray *args=[NSMutableArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
     //NSLog(@"%@",[args description]);
     //[0] command path
     //[1] qidos
     //[2] spool folder
     //[3] date (opcional)
     
    /*
     {
       "asseX":"https://serviciosridi.asse.uy/dcm4chee-arc/qido/DCM4CHEE/instances?Modality=MG&00080080=asseX&00081060=asseX&StudyDate=",
        ...
     }
     */
     
     //[1]qidos
     NSData *qidosData=[NSData dataWithContentsOfFile:[args[1] stringByExpandingTildeInPath]];
     if (!qidosData)
     {
       NSLog(@"bad path or json qidos file: %@",args[1]);
       exit(1);
     }

     NSDictionary *qidos=[NSJSONSerialization JSONObjectWithData:qidosData options:0 error:&error];
     if (!qidos)
     {
        NSLog(@"%@",error.description);
        exit(1);
     }
    
    //[2] spool path
     NSString *spoolPath=[args[2] stringByExpandingTildeInPath];
     for (NSString *qidoKey in [qidos allKeys])
     {
        
        NSString *keySpoolPath=[spoolPath stringByAppendingPathComponent:qidos[qidoKey]];
        if (
               ![fileManager fileExistsAtPath:keySpoolPath]
            && ![fileManager createDirectoryAtPath:keySpoolPath withIntermediateDirectories:YES attributes:nil error:&error]
           )
        {
           NSLog(@"%@",error.description);
           continue;
        }
        
        NSString *keyDASpoolPath=[keySpoolPath stringByAppendingPathComponent:DA];
        if (
               ![fileManager fileExistsAtPath:keyDASpoolPath]
            && ![fileManager createDirectoryAtPath:keyDASpoolPath withIntermediateDirectories:YES attributes:nil error:&error]
           )
        {
           NSLog(@"%@",error.description);
           continue;
        }
        
        //NSArray *Es=[fileManager contentsOfDirectoryAtPath:keyDASpoolPath error:&error];
      

#pragma mark qido
        NSURL *qidoURL=[NSURL URLWithString:[NSString stringWithFormat:@"%@%@",qidoKey,DA]];
        if (!qidoURL)
        {
           NSLog(@"ERROR cannot create url \"%@\":\"%@\"",qidos[qidoKey],[qidoURL absoluteString]);
           continue;
        }
        NSData *qidoResponse=[NSData dataWithContentsOfURL:qidoURL
                                                   options:NSDataReadingUncached
                                                     error:&error];
        if (!qidoResponse)
        {
           //NSURLConnection finished with error - code -1002
           NSLog(@"%@", error.description);
           continue;
        }
        if (![qidoResponse length]) continue;//no instance found

        
        NSArray *list = [NSJSONSerialization JSONObjectWithData:qidoResponse options:0 error:&error];
        if (!list)
        {
             NSLog(@"qido response to %@ not json. %@ %@",[qidoURL absoluteString],error.description,[[NSString alloc]initWithData:qidoResponse encoding:NSUTF8StringEncoding] );
             continue;
        }
        
        
        for (NSDictionary *instance in list)
        {
   #pragma mark - loop StudyInstanceUIDs

           NSString *EUID=[instance[@"0020000D"][@"Value"] firstObject];
           NSString *EUIDpath=[keyDASpoolPath stringByAppendingPathComponent:EUID];
           if (
                  ![fileManager fileExistsAtPath:EUIDpath]
               && ![fileManager createDirectoryAtPath:EUIDpath withIntermediateDirectories:YES attributes:nil error:&error]
              )
           {
              NSLog(@"%@",error.description);
              continue;
           }
           NSString *IUID=[instance[@"00080018"][@"Value"] firstObject];

           NSString *IUIDpath=[EUIDpath stringByAppendingPathComponent:IUID];
           
           if (
                 [fileManager fileExistsAtPath:IUIDpath]
               &&[fileManager fileExistsAtPath:[IUIDpath stringByAppendingPathExtension:@"OK"]]
           )
           {

#pragma mark download file
             NSString *RetrieveString=[instance[@"00081190"][@"Value"] firstObject];
             if (RetrieveString && RetrieveString.length)
             {
                NSURL *RetrieveURL=[NSURL URLWithString:RetrieveString];
                if (!RetrieveURL)
                {
                   NSLog(@"ERROR could not create URL from %@",RetrieveString);
                   continue;
                }
                NSData *downloaded=[NSData dataWithContentsOfURL:RetrieveURL
                                                         options:NSDataReadingUncached
                                                           error:&error];
                if (!downloaded)
                {
                   NSLog(@"ERROR response to %@: %@",RetrieveString,error.description);
                   continue;
                }

                                     
                if (downloaded.length == 0)
                {
                    NSLog(@"empty response to %@",RetrieveString);
                    continue;
                }
                 
                 //unzip
                 ZZArchive *archive = [ZZArchive archiveWithData:downloaded];
                 ZZArchiveEntry *firstEntry = archive.entries[0];
                 NSData *unzipped = [firstEntry newDataWithError:&error];
                 if (error!=nil)
                 {
                     NSLog(@"could NOT unzip response to %@: %@",RetrieveString,downloaded.description);
                     continue;
                 }
                 
                 [unzipped writeToFile:IUIDpath atomically:NO];
             }//end retrieveString
              
           }

        }
        

     }
  }
   return 0;
}
