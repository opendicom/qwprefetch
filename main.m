// Created by jacquesfauquex@opendicom.com on 2022-10-03.
// Copyright (c) 2022 opendicom.com. All rights reserved.

// branch created to create new b64uid repository from dicomweb

#import <Foundation/Foundation.h>
#import "ZZArchiveEntry.h"
#import "ZZArchive.h"
#import "ZZConstants.h"
#import "ZZChannel.h"
#import "ZZError.h"

NSFileManager *fileManager=nil;
BOOL isDir=false;
BOOL isNewSubdir=false;

//uint8 sopClength=0;
//NSRange sopClengthRange;
//uint8 sopIoffset=0;
//uint8 sopIlength=0;
//NSRange sopIlengthRange;
//NSRange sopIrange;
//NSRange sopIlastByteRange;
//uint8 sopIlastByte;

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

NSString *subdirB64(NSString *dir,NSString *uid, BOOL *isNewSubdir) {
   NSError *mkdirError=nil;
   NSString *subdirB64=[dir stringByAppendingPathComponent:b64(uid)];
   if (![fileManager fileExistsAtPath:subdirB64 isDirectory:&isDir])
   {
       if (![fileManager createDirectoryAtPath:subdirB64 withIntermediateDirectories:false attributes:nil error:&mkdirError])
       {
           NSLog(@"%@", mkdirError.description);
           exit(2);
       }
       *isNewSubdir=true;
       return subdirB64;
   }
   
   if (!isDir)
   {
      NSLog(@"path %@ exists but is not a folder",subdirB64);
      exit(2);
   }
   
   *isNewSubdir=false;
   return subdirB64;
}


int main(int argc, const char * argv[])
{
   Byte *uid=(Byte*)malloc(64);
   fileManager=[NSFileManager defaultManager];
   //sopClengthRange=NSMakeRange(0xE4, 1);
   //sopIlengthRange=NSMakeRange(NSNotFound, 1);
   //sopIrange=NSMakeRange(NSNotFound, 0);
   //sopIlastByte=NSMakeRange(NSNotFound, 1);
   @autoreleasepool {
    NSError *jsonError=nil;
    NSError *qidoError=nil;
    NSError *wadoError=nil;
    NSError *unzipError=nil;
    //http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    NSDateFormatter *DAFormatter = [[NSDateFormatter alloc] init];
    [DAFormatter setDateFormat:@"yyMMdd"];
    //NSDateFormatter *DTFormatter = [[NSDateFormatter alloc] init];
    //[DTFormatter setDateFormat:@"yyMMddhhmmss"];

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
     NSString *Da=nil;
     if (args.count==5) Da=args[4];
     else Da=[DAFormatter stringFromDate:[NSDate date]];
     NSArray *Ds=@[Da];

     for (NSString *D in Ds)
     {
         NSURL *qidoE=[NSURL URLWithString:[NSString stringWithFormat:@"%@/studies?StudyDate=%@",args[1],D]];
         if (!qidoE) return 3;
         NSData *qidoEdata=[NSData dataWithContentsOfURL:qidoE options:NSDataReadingUncached error:&qidoError];
         if (!qidoEdata)
         {
             //NSURLConnection finished with error - code -1002
             NSLog(@"%@", qidoError.description);
             return 3;
         }
         if (!qidoEdata.length) continue;//no instance found
         NSArray *Es = [NSJSONSerialization JSONObjectWithData:qidoEdata options:0 error:&jsonError];
         if (!Es)
         {
             NSLog(@"%@\r\%@",jsonError.description,[[NSString alloc]initWithData:qidoEdata encoding:NSUTF8StringEncoding] );
             return 3;
         }
         NSString *Db64path=subdirB64(path,D,&isNewSubdir);

        
#pragma mark - loop E

         for (NSDictionary *E in Es)
         {
            NSString *Euid=[E[@"0020000D"][@"Value"] firstObject];
            NSURL *qidoS=[NSURL URLWithString:[NSString stringWithFormat:@"%@/studies/%@/series?",args[1],Euid]];
            if (!qidoS) continue;
            NSData *qidoSdata=[NSData dataWithContentsOfURL:qidoS options:NSDataReadingUncached error:&qidoError];
            if (!qidoSdata)
            {
                //NSURLConnection finished with error - code -1002
                NSLog(@"%@", qidoError.description);
                return 4;
            }
            if (!qidoSdata.length) continue;//no instance found
            NSArray *Ss = [NSJSONSerialization JSONObjectWithData:qidoSdata options:0 error:&jsonError];
            if (!Ss)
            {
                NSLog(@"%@\r\%@",jsonError.description,[[NSString alloc]initWithData:qidoSdata encoding:NSUTF8StringEncoding] );
                return 4;
            }
            NSString *Eb64path=subdirB64(Db64path,D,&isNewSubdir);


#pragma mark loop S
            for (NSDictionary *S in Ss)
            {
               NSString *Suid=[E[@"0020000E"][@"Value"] firstObject];
               NSString *Sb64path=subdirB64(Eb64path,Suid,&isNewSubdir);

               NSMutableSet *Is=nil;
               //NSUInteger serverIcount=[[S[@"00201209)"][@"Value"] firstObject]unsignedIntegerValue];
               if (!isNewSubdir)
               {
                  Is=[NSMutableSet set];
                  
                  //check if the series dir already has contents
                  NSArray *contents=[fileManager contentsOfDirectoryAtPath:Sb64path error:nil];
                  for (NSString *name in contents)
                  {
                     if (![name hasPrefix:@"."]) [Is addObject:name];
                  }
               }
               
               //download
               NSString *RetrieveString=[S[@"00081190"][@"Value"] firstObject];
               if (!RetrieveString || !RetrieveString.length) continue;
               NSURL *RetrieveURL=[NSURL URLWithString:RetrieveString];
               if (!RetrieveURL)
               {
                  NSLog(@"ERROR could not create URL from %@",RetrieveString);
                  continue;
               }
               NSData *downloaded=[NSData dataWithContentsOfURL:RetrieveURL options:NSDataReadingUncached error:&wadoError];
               if (!downloaded)
               {
                  NSLog(@"ERROR response to %@: %@",RetrieveString,wadoError.description);
                  continue;
               }
               if (downloaded.length < 1000)
               {
                  NSLog(@"empty response to %@",RetrieveString);
                  continue;
               }

               ZZArchive *archive=[ZZArchive archiveWithData:downloaded];
               NSArray *entries=archive.entries;
#pragma mark loop I
               for (ZZArchiveEntry *entry in entries) {
                  NSData *Idata = [entry newDataWithError:&unzipError];
                  if (unzipError!=nil)
                  {
                     NSLog(@"could NOT unzip response to %@: %@",RetrieveString,unzipError.description);
                     continue;
                  }
                  //find sopuid
                  const Byte *Ibytes=Idata.bytes;
                  //SOPClass.length : byte[0xE4]
                  //[unzipped getBytes:&sopClength range:sopClengthRange];
                  //sopIlengthRange.location= 0xE4 + 0x02 + sopClength + 0x06;
                  //[unzipped getBytes:&sopIlength range:sopIlengthRange];

                  //sopIrange.location=sopIlengthRange.location+2;
                  //sopIlastByteRange.location=sopIrange.location + sopIlength -1;
                  //[unzipped getBytes:&sopIlastByte range:sopIlastByteRange];
                  //sopIrange.length=sopIlength - (sopIlastByte==0x00);
                  
                  NSUInteger Ioffset = 0xE4 + 0x02 + Ibytes[0xE4] + 0x08;
                  NSUInteger Ilength = Ibytes[Ioffset - 0x02];
                  NSUInteger Ilast = Ibytes[Ioffset + Ilength -1];
                  Ilength -= (Ilast == 0x00);
                  [Idata getBytes:&uid range:NSMakeRange(Ioffset, Ilength)];
                  NSString *I=[[NSString alloc]initWithBytes:&uid length:Ilength encoding:NSASCIIStringEncoding];
                  
                  NSString *Ib64=b64(I);
                  if (Is && [Is containsObject:Ib64])
                  {
                     NSLog(@"already exists: %@/%@",Sb64path,Ib64);
                  }
                  else
                  {
                     [unzipped writeToFile:[Sb64path stringByAppendingPathComponent:Ib64] atomically:NO];
                  }
              }
           }
        }
     }
  }
  return 0;
}
