//
//  DHTNode.h
//  DHTIOS
//
//  Created by Andy on 8/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DHT.h"

typedef NS_ENUM(NSUInteger, DHTNodeState) {
    DHTNodeStateUnknown = 0,
    DHTNodeStateGood = 1,
    DHTNodeStateQuestionable = 2,
    DHTNodeStateBad = 3,
};

typedef NS_ENUM(NSUInteger, DHTKRPCQuery) {
    DHTKRPCQueryPing,
    DHTKRPCQueryAnnounce,
    DHTKRPCQueryFindPeer,
    DHTKRPCQueryError
};

//201	Generic Error
//202	Server Error
//203	Protocol Error, such as a malformed packet, invalid arguments, or bad token
//204	Method Unknown
typedef NS_ENUM(NSUInteger, DHTKRPCErrCode) {
    DHTKRPCErrCodeGenericError = 201,
    DHTKRPCErrCodeServerError = 202,
    DHTKRPCErrCodeProtocolError = 203,
    DHTKRPCErrCodeMethodUknown = 204,
};

@protocol DHTNodeDelegate;

@interface DHTNode : NSObject

@property (nonatomic, weak) id<DHTNodeDelegate> delegate;

@property (nonatomic, assign, readonly) NSData *nodeId;
@property (nonatomic, assign, readonly) uint32_t ipAddress;
@property (nonatomic, assign, readonly) uint16_t port;
@property (atomic, assign, readonly) DHTNodeState pingState;
@property (nonatomic, weak) DHT *dhtManager;

// Routing
@property (nonatomic, strong) DHTNode *leftNode;
@property (nonatomic, strong) DHTNode *rightNode;

-(DHTNode *)initAndListenWithIpAddress:(NSString *)ipAddress andPort:(uint16_t)port;
-(DHTNode *)initAndListenWithIpAddress:(NSString *)ipAddress andPort:(uint16_t)port nodeId:(NSData *)nodeId;
-(DHTNode *)initWithNodeContactInfo:(NSData *)nodeContactInfo;
-(DHTNode *)initWithNodeID:(NSData *)nodeId ipAddressString:(NSString *)ipAddress port:(uint16_t)port;
-(DHTNode *)initWithNodeID:(NSData *)nodeId ipAddressInt:(uint32_t)ipAddress port:(uint16_t)port;

-(void)ping;
// get_peers
-(void)getPeersForInfoHash:(NSData *)infoHash;
// announce_peer
-(void)announcePeerForInfoHash:(NSData *)infoHash; // uses the current UDP port
-(void)announcePeerForInfoHash:(NSData *)infoHash port:(NSUInteger)port;
// find_node
-(void)findNodeWithNodeID:(NSData *)nodeId;

// Get info
-(NSString *)nodeIdString;
-(NSString *)ipAddressString;
-(NSData *)nodeContactInfo;
-(NSData *)peerContactInfo;

@end

@protocol DHTNodeDelegate <NSObject>
-(void)dhtNode:(DHTNode *)node didChangeState:(DHTNodeState)state;
@end
