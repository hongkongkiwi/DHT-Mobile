//
//  DHT.h
//  DHTIOS
//
//  Created by Andy on 8/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "M13OrderedDictionary.h"

@class DHTNode;

@interface DHT : NSObject
@property (nonatomic, strong, readonly) DHTNode *rootNode;

-(DHT *)initWithBootstrapNodes:(NSArray *)nodes;
-(DHT *)initWithBootstrapServers:(NSArray *)servers;
@end