//  Created by jacquesfauquex@opendicom.com on 2014-07-30.
//  Copyright (c) 2022 opendicom.com. All rights reserved.

#import <Foundation/Foundation.h>
#import "ZZArchiveEntry.h"
#import "ZZArchive.h"
#import "ZZConstants.h"
#import "ZZChannel.h"
#import "ZZError.h"

BOOL addSubdirs(NSFileManager *fileManager, NSString *dir, NSMutableSet *set)
{
    NSArray *array=[fileManager contentsOfDirectoryAtPath:dir error:nil];
    BOOL isDir=false;
    BOOL hasSubdir=false;
    for (NSString *content in array)
    {
        NSString *subdir=[dir stringByAppendingPathComponent:content];
        if ([fileManager fileExistsAtPath:subdir isDirectory:&isDir] && isDir)
            hasSubdir|=addSubdirs(fileManager, subdir, set);
    }
    if (!hasSubdir) [set addObject:dir];
    return true;
}

int main(int argc, const char * argv[])
{
 @autoreleasepool {
     
    NSError *error=nil;

    NSData *xv=[@"1.2.840.10008.1.2.4.90" dataUsingEncoding:NSASCIIStringEncoding];//jpeg2000 lossless only
    NSData *xs=[@"1.2.840.10008.1.2.4.70" dataUsingEncoding:NSASCIIStringEncoding];//jpeg lossless
    NSData *xe=[@"1.2.840.10008.1.2.1" dataUsingEncoding:NSASCIIStringEncoding];//explicit little endian
    NSData *xi=[@"1.2.840.10008.1.2" dataUsingEncoding:NSASCIIStringEncoding];//implicit little endian
    NSRange firstKbRange=NSMakeRange(0, 1024);
#pragma mark init
     

    NSFileManager *fileManager=[NSFileManager defaultManager];

    //http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    NSDateFormatter *DAFormatter = [[NSDateFormatter alloc] init];
    [DAFormatter setDateFormat:@"yyyyMMdd"];

    //NSDateFormatter *DTFormatter = [[NSDateFormatter alloc] init];
    //[DTFormatter setDateFormat:@"yyyyMMddhhmmss"];

#pragma mark - args
     
     NSMutableArray *args=[NSMutableArray arrayWithArray:[[NSProcessInfo processInfo] arguments]];
     //NSLog(@"%@",[args description]);
     //[0] command path
     //[1] qido url
     //[2] remote reporting orgs json
     //[3] spool folder
     //[4] date (opcional)
     
#pragma mark [2] remote reporting orgs json
     NSData *reportingData=[NSData dataWithContentsOfFile:[args[2] stringByExpandingTildeInPath]];
     if (!reportingData)
     {
       NSLog(@"bad remote reporting orgs path or json file: %@",args[2]);
       exit(1);
     }
     NSDictionary *reporting=[NSJSONSerialization JSONObjectWithData:reportingData options:0 error:&error];
     if (!reporting)
     {
        NSLog(@"%@",error.description);
        exit(1);
     }
     //NSLog(@"%@",reporting.description);
     NSSet *convenios=[NSSet setWithArray:[reporting allKeys]];
     
#pragma mark [3] spool path
     NSString *spoolPath=[args[3] stringByExpandingTildeInPath];
     
     NSMutableSet *paths=[NSMutableSet set];
     addSubdirs(fileManager, spoolPath, paths);
     
     NSMutableArray *transferSyntaxes=[NSMutableArray arrayWithArray:[fileManager contentsOfDirectoryAtPath:spoolPath error:nil]];
     BOOL isDir=false;
     
     for (int index=(int)(transferSyntaxes.count)-1; index > -1; index-- )
     {
         if (
               ![fileManager fileExistsAtPath:[spoolPath stringByAppendingPathComponent:transferSyntaxes[index]] isDirectory:&isDir]
             ||! isDir
             ||[transferSyntaxes[index] isEqualToString:@".DS_Store"]
             )
             [transferSyntaxes removeObjectAtIndex:index];
     }
     
#pragma mark [4] date
     NSString *DA=nil;
     if (args.count==5) DA=args[4];
     else DA=[DAFormatter stringFromDate:[NSDate date]];
     
#pragma mark [1] qido url
     /*
      one url only for all orgs!
      qido institution 00080080 does not work in dcm4chee-arc of Asse
      */
     NSString *urlString=args[1];
     NSURL *qidoURL=[NSURL URLWithString:[urlString stringByAppendingString:DA]];
     if (!qidoURL) return 1;
     NSData *qidoResponse=[NSData dataWithContentsOfURL:qidoURL options:NSDataReadingUncached error:&error];
     if (!qidoResponse)
     {
        //NSURLConnection finished with error - code -1002
        NSLog(@"%@", error.description);
         return 2;
     }
     if (![qidoResponse length]) return 3;//no instance found
     NSArray *list = [NSJSONSerialization JSONObjectWithData:qidoResponse options:0 error:&error];
     if (!list)
     {
          NSLog(@"%@\r\%@",error.description,[[NSString alloc]initWithData:qidoResponse encoding:NSUTF8StringEncoding] );
          return 4;
     }
     
#pragma mark - loop InstanceUIDs

     for (NSDictionary *item in list)
     {
         NSString *Institution=[item[@"00080080"][@"Value"] firstObject];
         if (![convenios containsObject:Institution]) continue;
         
         if (![reporting[Institution] isEqualToString:@"*"])
         {
             if (![[item[@"00081060"][@"Value"] firstObject][@"Alphabetic"] hasPrefix:reporting[Institution]]) continue;
         }
         
#pragma mark file already downloaded ?
         NSString *EUID=[item[@"0020000D"][@"Value"] firstObject];
         NSString *IUID=[item[@"00080018"][@"Value"] firstObject];

         
         //find study in spool
         NSString *path=nil;
         for (NSString *transferSyntax in transferSyntaxes)
         {
             NSString *tempPath=[NSString stringWithFormat:@"%@/%@/%@/%@/%@",
                             spoolPath,
                             transferSyntax,
                             Institution,
                             DA,
                             EUID];
             if ([paths containsObject:tempPath])
             {
                 path=[NSString stringWithString:tempPath];
                 break;
             }
         }
         if (path)
         {
             NSString *IUIDpath=[[path stringByAppendingPathComponent:IUID] stringByAppendingPathExtension:@"dcm"];
             if (
                   [fileManager fileExistsAtPath:IUIDpath]
                 ||[fileManager fileExistsAtPath:[IUIDpath stringByAppendingPathExtension:@"done"]]
                 )
                 continue;
         }
         
         //instance not dowloaded or successfully sent to workstation

#pragma mark download file
         //NSString *SUID=[instance[@"0020000E"][@"Value"] firstObject];

         NSString *RetrieveString=[item[@"00081190"][@"Value"] firstObject];
         if (RetrieveString && RetrieveString.length)
         {
            NSURL *RetrieveURL=[NSURL URLWithString:RetrieveString];
            if (!RetrieveURL)
            {
                NSLog(@"ERROR could not create URL from %@",RetrieveString);
                continue;
            }
            NSData *downloaded=[NSData dataWithContentsOfURL:RetrieveURL options:NSDataReadingUncached error:&error];
            if (!downloaded)
            {
               NSLog(@"ERROR response to %@: %@",RetrieveString,error.description);
               continue;
            }

                                     
            if (downloaded.length < 1000)
            {
               NSLog(@"empty response to %@",RetrieveString);
               continue;
            }
                 
#pragma mark unzip
            ZZArchive *archive = [ZZArchive archiveWithData:downloaded];
            ZZArchiveEntry *firstEntry = archive.entries[0];
            NSData *unzipped = [firstEntry newDataWithError:&error];
            if (error!=nil)
            {
               NSLog(@"could NOT unzip response to %@: %@",RetrieveString,downloaded.description);
                     continue;
            }
            
#pragma mark find transfer syntax
            NSString *transferSyntax=nil;
            NSRange xvRange=[unzipped rangeOfData:xv options:0 range:firstKbRange];
            if (xvRange.location==NSNotFound)
            {
                NSRange xsRange=[unzipped rangeOfData:xs options:0 range:firstKbRange];
                if (xsRange.location==NSNotFound)
                {
                    NSRange xeRange=[unzipped rangeOfData:xe options:0 range:firstKbRange];
                    if (xeRange.location==NSNotFound)
                    {
                        NSRange xiRange=[unzipped rangeOfData:xi options:0 range:firstKbRange];
                        if (xiRange.location==NSNotFound)
                        {
                            NSLog(@"unknown transfer syntax for  %@",RetrieveString);
                            transferSyntax=@"unknown";
                        }
                        else transferSyntax=@"-xi";
                    }
                    else transferSyntax=@"-xe";
                }
                else transferSyntax=@"-xs";
            }
            else transferSyntax=@"-xv";
             
#pragma mark mkdir?
            if (!path)
            {
                path=[NSString stringWithFormat:@"%@/%@/%@/%@/%@",
                                spoolPath,
                                transferSyntax,
                                Institution,
                                DA,
                                EUID];
               [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
               [paths addObject:path];
            }

#pragma mark write file
             [unzipped writeToFile:[[path stringByAppendingPathComponent:IUID] stringByAppendingPathExtension:@"dcm"] atomically:NO];
        }
     }
  }
  return 0;
}
