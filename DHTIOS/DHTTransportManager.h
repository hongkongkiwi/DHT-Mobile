//
//  DHTTransportManager.h
//  DHTIOS
//
//  Created by Andy on 9/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DHTIncomingTransportDelegate;

@interface DHTTransportManager : NSObject

@property (nonatomic, weak) id<DHTIncomingTransportDelegate> incomingMessageDelegate;
@property (nonatomic, assign, readonly) bool isListening;

-(bool)listenWithPort:(uint16_t)port;
-(void)sendMessage:(NSData *)messageData toHost:(NSString *)toHost toPort:(uint16_t)toPort;

@end

@protocol DHTIncomingTransportDelegate <NSObject>
-(void)incomingMessage:(NSData *)message fromHost:(NSString *)fromHost fromPort:(uint16_t)fromPort;
@end
