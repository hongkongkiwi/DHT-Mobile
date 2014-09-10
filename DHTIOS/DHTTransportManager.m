//
//  DHTTransportManager.m
//  DHTIOS
//
//  Created by Andy on 9/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import "DHTTransportManager.h"
#import "GCDAsyncUdpSocket.h"

typedef NS_ENUM(NSUInteger, DHTUDPTag) {
    DHTUDPTagKRPC
};

@interface DHTTransportManager() <GCDAsyncUdpSocketDelegate>
@property (nonatomic, strong) NSMutableArray *socketArray;
@property (nonatomic, strong) GCDAsyncUdpSocket *udpSocket;
@end

@implementation DHTTransportManager

-(DHTTransportManager *)init {
    if (self = [super init]) {
        _isListening = NO;
    }
    return self;
}

-(bool)listenWithPort:(uint16_t)port {
    self.udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![self.udpSocket bindToPort:port error:&error]) {
        NSLog(@"Error binding to port %d - %@", port, error);
         _isListening = NO;
        return NO;
    }
    if (![self.udpSocket beginReceiving:&error]) {
        NSLog(@"Error receiving data - %@", error);
         _isListening = NO;
        return NO;
    }
    _isListening = YES;
    return YES;
}

// Used by the DHTNodeDelegate to send outgoing messages
-(void)sendMessage:(NSData *)messageData toAddress:(NSString *)toAddress toPort:(uint16_t)toPort {
    [self.udpSocket sendData:messageData toHost:toAddress port:toPort withTimeout:-1 tag:DHTUDPTagKRPC];
}

// GCDAsyncSocket delegate called when receiving messages
- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    NSString *host = nil;
    uint16_t port = 0;
    [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
    [self.incomingMessageDelegate incomingMessage:data fromHost:host fromPort:port];
}

@end