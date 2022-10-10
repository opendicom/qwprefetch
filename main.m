// Created by jacquesfauquex@opendicom.com on 2022-10-03.
// Copyright (c) 2022 opendicom.com. All rights reserved.

// branch dedicated to creation of b64uid repository from dicomweb
//compulsory 0-5
//optionals 6-8

#import <Foundation/Foundation.h>
#import "NSData+DICOMweb.h"

enum {
   command=0,
   queryEndpoint,
   retrieveEndpoint,
   repositoryPath,
   filter
} argsEnum;

BOOL useB64uid=false;
NSString *Q=nil;
NSString *R=nil;
NSFileManager *fileManager=nil;
BOOL isDir=false;
BOOL isNewSubdir=false;

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

NSString *subdirB64(NSString *dir,NSString *uid, BOOL useB64uid, BOOL *isNewSubdir) {
   NSError *mkdirError=nil;
   NSString *subdirB64;
   if (useB64uid)subdirB64=[dir stringByAppendingPathComponent:b64(uid)];
   else subdirB64=[dir stringByAppendingPathComponent:uid];
   
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

void Eprocess(NSString *Epath, NSString* E)
{
   NSError *error=nil;
   NSURL *qidoS=[NSURL URLWithString:[NSString stringWithFormat:@"%@/studies/%@/series?",R,E]];
   if (!qidoS) return;
   NSData *qidoSdata=[NSData dataWithContentsOfURL:qidoS options:NSDataReadingUncached error:&error];
   if (!qidoSdata)
   {
       //NSURLConnection finished with error - code -1002
       NSLog(@"%@", error.description);
       exit(4);
   }
   if (!qidoSdata.length) return;//no instance found
   NSArray *Sdicts = [NSJSONSerialization JSONObjectWithData:qidoSdata options:0 error:&error];
   if (!Sdicts)
   {
       NSLog(@"%@\r\%@",error.description,[[NSString alloc]initWithData:qidoSdata encoding:NSUTF8StringEncoding] );
       exit(4);
   }
   NSString *Eb64path=subdirB64(Epath,E,useB64uid,&isNewSubdir);


#pragma mark loop S
   for (NSDictionary *Sdict in Sdicts)
   {
      NSString *S=[Sdict[@"0020000E"][@"Value"] firstObject];
      NSString *Sb64path=subdirB64(Eb64path,S,useB64uid,&isNewSubdir);
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
      
      NSMutableDictionary *Iranges=[NSMutableDictionary dictionary];
      NSData *data=[NSData syncRetrieveMultiDICMendpoint:R E:E S:S I:nil resultPointers:Iranges];
      
      for (NSString* I in Iranges)
      {
         NSString *Ib64;
         if (useB64uid) Ib64=b64(I);
         else Ib64=I;
         if (Is && [Is containsObject:Ib64])
         {
            NSLog(@"already exists: %@/%@",Sb64path,Ib64);
         }
         else
         {
            NSData *Idata=[data subdataWithRange:[Iranges[I] rangeValue]];
            [Idata writeToFile:[Sb64path stringByAppendingPathComponent:Ib64] atomically:NO];
         }
      }//I
   }//Sdict
}//Edict


int main(int argc, const char * argv[])
{
    NSError *error=nil;
    fileManager=[NSFileManager defaultManager];
    @autoreleasepool {
    //http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
    NSDateFormatter *DAFormatter = [[NSDateFormatter alloc] init];
    [DAFormatter setDateFormat:@"yyMMdd"];

#pragma mark - args
     
     NSArray *args=[[NSProcessInfo processInfo] arguments];
     //NSLog(@"%@",[args description]);
     Q=args[queryEndpoint];
     R=args[retrieveEndpoint];

     NSString *path=[args[repositoryPath] stringByExpandingTildeInPath];
     if (![fileManager fileExistsAtPath:path isDirectory:&isDir] || !isDir)
     {
         NSLog(@"bad path:%@",path);
         exit(1);
     }

       
     NSString *queryFilter=nil;
     NSArray *queryMatches=nil;
     //filter is or E or D-D
     if ([args[filter] containsString:@"-"])
     {
        queryFilter=@"%@/studies?StudyDate=20%@";
        NSArray *fromto=[args[filter] componentsSeparatedByString:@"-"];
        if ([fromto[0] isEqualToString:fromto[1]]) queryMatches=@[fromto[0]];
//TODO Ds range
     }
     else //EUID filter
     {
        queryFilter=@"%@/studies?StudyInstanceUID=%@";
        queryMatches=@[args[filter]];
     }

       
     for (NSString *queryMatch in queryMatches)
     {
         NSURL *qidoE=[NSURL URLWithString:[NSString stringWithFormat:queryFilter,args[queryEndpoint],queryMatch]];
         NSData *qidoEdata=[NSData dataWithContentsOfURL:qidoE options:NSDataReadingUncached error:&error];
         if (!qidoEdata)
         {
             //NSURLConnection finished with error - code -1002
             NSLog(@"%@", error.description);
             return 3;
         }
         if (!qidoEdata.length) continue;//no instance found
         NSArray *Edicts = [NSJSONSerialization JSONObjectWithData:qidoEdata options:0 error:&error];
         if (!Edicts)
         {
             NSLog(@"%@\r\%@",error.description,[[NSString alloc]initWithData:qidoEdata encoding:NSUTF8StringEncoding] );
             return 3;
         }
         for (NSDictionary *Edict in Edicts) {
           Eprocess(
                     subdirB64(path,queryMatch,useB64uid,&isNewSubdir),
                     [Edict[@"0020000D"][@"Value"] firstObject]
                    );
         }
      }

       
   }//autorelease pool
   return 0;
}//main
