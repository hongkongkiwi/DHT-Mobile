//
//  BEncoding.h
//  DHTIOS
//
//  Created by Andy on 9/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BData.h"

@interface BEncoding : NSObject

+(NSData *)encodeObject:(NSDictionary *)dict;
+(NSArray *)decodeObject:(NSData *)sourceData;

+ (NSNumber *)bdecodeInt:(BData *)bData withSeperator:(char)seperator;
+ (NSNumber *)bdecodeInt:(BData *)bData;
+ (NSString *) bdecodeString:(BData *)bData;
+ (NSArray *) bdecodeArray:(BData *)bData;
+ (NSDictionary *) bdecodeDict:(BData *)bData;
+ (NSObject *)bdecode:(BData *) bData;

+(void)bencode:(NSObject *)obj toBuffer:(NSMutableString *)buffer;

@end

