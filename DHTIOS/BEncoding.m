//
//  BEncoding.m
//  DHTIOS
//
//  Created by Andy on 9/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import "BEncoding.h"
#import "BData.h"

@implementation BEncoding
+(NSData *)encodeObject:(NSDictionary *)dict {
    
    NSMutableString *stringBuffer = [[NSMutableString alloc] init];
    
    [self bencode:dict toBuffer:stringBuffer];
    
    return [stringBuffer dataUsingEncoding: NSASCIIStringEncoding];
    
}

+(NSArray *)decodeObject:(NSData *)sourceData {
    
    NSMutableArray* array = [[NSMutableArray alloc] init];
    BData *bData = [[BData alloc] initWithData:sourceData];
    
    while(![bData isFinished]) {
        [array addObject:[self bdecodeDict:bData]];
    }
    
    bData = nil;
    
    return array;
}

+ (NSNumber *)bdecodeInt:(BData *)bData withSeperator:(char)seperator {
    
    NSMutableString *stringBuffer = [[NSMutableString alloc] init];
    
    if (seperator == 'e') {
        [bData getNext]; // Burn the i
    }
    
    while ([bData peekNext] != seperator) {
        [stringBuffer appendFormat:@"%c", [bData getNext]];
    }
    
    [bData getNext]; // Burn the seperator
    
    NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber * myNumber = [f numberFromString:stringBuffer];
    f = nil;
    
    return myNumber;
}

+ (NSNumber *)bdecodeInt:(BData *)bData {
    
    return [self bdecodeInt:bData withSeperator:'e'];
}

+ (NSString *) bdecodeString:(BData *)bData {
    
    NSMutableString *stringBuffer = [[NSMutableString alloc] init];
    NSNumber *length = [self bdecodeInt:bData withSeperator:':'];
    int l = [length intValue];
    
    for(int i = 0; i < l; i++) {
        [stringBuffer appendFormat:@"%c", [bData getNext]];
    }
    
    return stringBuffer;
}

+ (NSArray *) bdecodeArray:(BData *)bData {
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    [bData getNext]; // Burn the l
    
    while ([bData peekNext] != 'e') {
        
        NSObject *object = [self bdecode:bData];
        
        [array addObject:object];
    }
    
    [bData getNext]; // Burn the e
    
    return array;
}

+ (NSDictionary *) bdecodeDict:(BData *)bData {
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    [bData getNext]; // Burn the d
    
    while ([bData peekNext] != 'e') {
        NSString *key = [self bdecodeString:bData];
        NSObject *object = [self bdecode:bData];
        
        [dict setObject:object forKey:key];
    }
    
    [bData getNext]; // Burn the e
    
    return dict;
}

+ (NSObject *)bdecode:(BData *) bData {
    
    char c = [bData peekNext];
    
    if (c == 'd') {
        return [self bdecodeDict:bData];
    } else if (c == 'l') {
        return [self bdecodeArray:bData];
    } else if (c == 'i') {
        return [self bdecodeInt:bData];
    } else {
        return [self bdecodeString:bData];
    }
}

+(void)bencode:(NSObject *)object toBuffer:(NSMutableString *)buffer {
    
    if ([object isKindOfClass:[NSData class]])
    {
        // Don't support this yet
    }
    if ([object isKindOfClass:[NSString class]])
    {
        NSString *string = (NSString *)object;
        
        [buffer appendFormat:@"%d:%@", [string length], string];
    }
    else if ([object isKindOfClass:[NSNumber class]])
    {
        NSNumber *number = (NSNumber *)object;
        
        [buffer appendFormat:@"i%de", [number intValue]];
    }
    else if ([object isKindOfClass:[NSArray class]])
    {
        NSArray *array = (NSArray *)object;
        [buffer appendString:@"l"];
        
        for (id item in array) {
            [self bencode:item toBuffer:buffer];
        }
        
        [buffer appendString:@"e"];
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        
        NSDictionary *dict = (NSDictionary *)object;
        [buffer appendString:@"d"];
        
        for (id key in dict) {
            [self bencode:key toBuffer:buffer];
            [self bencode:[dict objectForKey:key] toBuffer:buffer];
        }
        
        [buffer appendString:@"e"];
    }
    
}
@end
