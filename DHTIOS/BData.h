//
//  BData.h
//  DHTIOS
//
//  Created by Andy on 9/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BData : NSObject {
@private
    char* data;
    NSUInteger index;
    NSUInteger length;
    
}

- (id)initWithData:(NSData*)sourceData;

-(NSUInteger)getLength;
-(bool) isFinished;
-(char) getNext;
-(char) peekNext;

@end