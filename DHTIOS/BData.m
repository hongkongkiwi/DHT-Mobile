//
//  BData.m
//  DHTIOS
//
//  Created by Andy on 9/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import "BData.h"

@implementation BData

- (id)initWithData:(NSData*)sourceData
{
    self = [super init];
    if (self) {
        
        index = 0;
        length = [sourceData length];
        
        data = malloc(length);
        [sourceData getBytes:data length:length];
    }
    
    return self;
}


-(NSUInteger)getLength {
    
    return length;
}

-(bool) isFinished {
    
    return (index >= length);
}

-(char) getNext {
    
    char c = data[index];
    index++;
    
    return c;
}

-(char) peekNext {
    
    return data[index];
}


- (void)dealloc
{
    free(data);
}

@end
