// Created by jacquesfauquex@opendicom.com on 2022-10-03.
// Copyright (c) 2022 opendicom.com. All rights reserved.

// branch created to create new b64uid repository from dicomweb

#import <Foundation/Foundation.h>
#import "ZZArchiveEntry.h"
#import "ZZArchive.h"
#import "ZZConstants.h"
#import "ZZChannel.h"
#import "ZZError.h"

NSString *B64CHAR[]={
@"-", @"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8",
@"9", @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"I",
@"J", @"K", @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S",
@"T", @"U", @"V", @"W", @"X", @"Y", @"Z", @"_", @"a", @"b",
@"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l",
@"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t", @"u", @"v",
@"w", @"x", @"y", @"z"
};

char u8u4( const char *byte_array, NSUInteger *idx) {
    // returns half_byte
    // updates idx
    
    // u4=half byte (0-15)
    // 0x0   1.2.840.10008.
    // 0x1   .
    // 0x2   0.
    // 0x3   0
    // 0x4   1.
    // 0x5   1
    // 0x6   2.
    // 0x7   2
    // 0x8   3.
    // 0x9   3
    // 0xA   4
    // 0xB   5
    // 0xC   6
    // 0xD   7
    // 0xE   8
    // 0xF   9
    
    char cur_byte = byte_array[*idx];
    switch (cur_byte) {
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            *idx += 1;
            return cur_byte - 0x2A;
        case '.':
            *idx += 1;
            return 0x01;
        case '0':
        case '2':
        case '3': {
            if (byte_array[*idx+1] == '.')  {
                *idx += 2;
                return cur_byte + cur_byte - 0x5E;
            } else {
                *idx += 1;
                return cur_byte + cur_byte - 0x5D;
            }
        }
        case '1': {
            if (byte_array[*idx+1] == '.') {
                if (   sizeof(byte_array) - *idx > 14
                    && byte_array[*idx+2]  == '2'
                    && byte_array[*idx+3]  == '.'
                    && byte_array[*idx+4]  == '8'
                    && byte_array[*idx+5]  == '4'
                    && byte_array[*idx+6]  == '0'
                    && byte_array[*idx+7]  == '.'
                    && byte_array[*idx+8]  == '1'
                    && byte_array[*idx+9]  == '0'
                    && byte_array[*idx+10] == '0'
                    && byte_array[*idx+11] == '0'
                    && byte_array[*idx+12] == '8'
                    && byte_array[*idx+13] == '.'
                    )
                {
                    *idx += 14;
                    return 0x0;
                }
                else
                {
                    *idx += 2;
                    return 0x4;
                }
            } else {
                *idx += 1;
                return cur_byte + cur_byte - 0x5D;
            }
        }
        default:
            return 0xFF;
    }
}

NSString* b64(NSString* uidString){
    if (!uidString) return nil;
    NSUInteger length=uidString.length;
    if (length==0) return @"";
    const char *array=[[uidString stringByAppendingString:@".."] cStringUsingEncoding:NSUTF8StringEncoding];
    NSUInteger index=0;
    unsigned char u4a,u4b,u4c;
    NSMutableString *b64String=[NSMutableString stringWithCapacity:(length+1)/2];
    while (index < length)
    {
        u4a=u8u4(array,&index);
        if (u4a > 0x10) return nil;
        u4b=u8u4(array,&index);
        if (u4b > 0x10) return nil;
        u4c=u8u4(array,&index);
        if (u4c > 0x10) return nil;
        [b64String appendString:B64CHAR[(u4a<<2) + (u4b>>2)]];
        [b64String appendString:B64CHAR[((u4b & 0x03) << 4) + u4c]];
    }
    return [NSString stringWithString:b64String];
}

int main(int argc, const char * argv[])
{
 @autoreleasepool {
    NSError *error=nil;
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
     //[1] qido endpoint
     //[2] wado endpoint
     NSString *path=[args[3] stringByExpandingTildeInPath];
     BOOL isDir=false;
     if (![fileManager fileExistsAtPath:path isDirectory:&isDir] || !isDir)
     {
         NSLog(@"bad path:%@",path);
         exit(1);
     }
     //[4] date DAa (or startdate if there is [5] end date DAz
     NSString *DAa=nil;
     if (args.count==5) DAa=args[4];
     else DAa=[DAFormatter stringFromDate:[NSDate date]];
     NSArray *DAs=@[DAa];

     for (NSString *DA in DAs)
     {
         NSURL *qidoE=[NSURL URLWithString:[NSString stringWithFormat:@"%@/studies?StudyDate=%@",args[1],DA]];
         if (!qidoE) return 1;
         NSData *qidoEdata=[NSData dataWithContentsOfURL:qidoE options:NSDataReadingUncached error:&error];
         if (!qidoEdata)
         {
             //NSURLConnection finished with error - code -1002
             NSLog(@"%@", error.description);
             return 2;
         }
         if (!qidoEdata.length) continue;//no instance found
         NSArray *Es = [NSJSONSerialization JSONObjectWithData:qidoEdata options:0 error:&error];
         if (!Es)
         {
             NSLog(@"%@\r\%@",error.description,[[NSString alloc]initWithData:qidoEdata encoding:NSUTF8StringEncoding] );
             return 4;
         }
         NSString *DApath=[path stringByAppendingPathComponent:DA];
         if (![fileManager fileExistsAtPath:DApath isDirectory:&isDir])
         {
             if (![fileManager createDirectoryAtPath:DApath withIntermediateDirectories:false attributes:nil error:&error])
             {
                 NSLog(@"%@", error.description);
                 return 4;
             }
         }
         else if (!isDir)
         {
             NSLog(@"path %@ exists but is not a folder",DApath);
             return 4;
         }

#pragma mark - loop E

         for (NSDictionary *E in Es)
         {
             NSString *Euid=[item[@"0020000D "][@"Value"] firstObject];

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
