//
//  DHTNode.m
//  DHTIOS
//
//  Created by Andy on 8/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import "DHTNode.h"
#import "NAChloride.h"
#import "SodiumObjc.h"
#import "GCDTimer.h"
#import "NSData+XORd.h"
#import "DHTTransportManager.h"
#import "BEncoding.h"

@interface DHTNode()
@property (nonatomic, strong) GCDTimer *pingTimer; // timer to reping node
@property (nonatomic, assign) NSUInteger pingAttempts; // How many attempts to ping this node
@property (nonatomic, strong) NSDate *lastSeen;

@property (nonatomic, strong) M13MutableOrderedDictionary *infoHashes; // Info hashes we are storing
@property (nonatomic, strong) M13MutableOrderedDictionary *issuedTokens; // tokens we have issued
@property (nonatomic, strong) DHTTransportManager *transportManager;

@property (nonatomic, strong) M13MutableOrderedDictionary *transactionIdsUsed;
@property (nonatomic, strong) NSString *lastTransactionId;

@property (nonatomic, strong) NSMutableArray *buckets;
@end

NSUInteger const MAX_BUCKET_SIZE = 8;

NSString *const FIND_NODE = @"find_node";
NSString *const ANNOUNCE_PEER = @"announce_peer";
NSString *const PING = @"ping";
NSString *const GET_PEERS = @"get_peers";

@implementation DHTNode

@synthesize pingState;

// Setup some basic class stuff
-(DHTNode *)init {
    if (self = [super init]) {
        self.buckets = [NSMutableArray new];
        [self.buckets addObject:@[]];
        [self setPingState:DHTNodeStateUnknown];
        self.lastSeen = [NSDate new];
        self.transportManager = [[DHTTransportManager alloc] init];
    }
    return self;
}

// This is mostly used when initing the node ourself
-(DHTNode *)initAndListenWithIpAddress:(NSString *)ipAddress andPort:(uint16_t)port {
    return [self initAndListenWithIpAddress:ipAddress andPort:port nodeId:nil]; // pass nil here because we want a random generated nodeId
}

-(DHTNode *)initAndListenWithIpAddress:(NSString *)ipAddress andPort:(uint16_t)port nodeId:(NSData *)nodeId {
    NSArray *ipExplode = [ipAddress componentsSeparatedByString:@"."];
    int seg1 = [ipExplode[0] intValue];
    int seg2 = [ipExplode[1] intValue];
    int seg3 = [ipExplode[2] intValue];
    int seg4 = [ipExplode[3] intValue];
    
    uint32_t newIP = 0;
    newIP |= (uint32_t)((seg1 & 0xFF) << 24);
    newIP |= (uint32_t)((seg2 & 0xFF) << 16);
    newIP |= (uint32_t)((seg3 & 0xFF) << 8);
    newIP |= (uint32_t)((seg4 & 0xFF) << 0);
    
    [self.transportManager listenWithPort:port];

    return [self initWithNodeID:nodeId ipAddressInt:newIP port:port];
}

// This is the important part
-(DHTNode *)initWithNodeContactInfo:(NSData *)nodeContactInfo {
    NSData *nodeId = [nodeContactInfo subdataWithRange:NSMakeRange(0, 20)];
    uint32_t ipAddressInt;
    [nodeContactInfo getBytes:&ipAddressInt range:NSMakeRange(20, 4)];
    uint16_t port;
    [nodeContactInfo getBytes:&port range:NSMakeRange(24, 2)];
    
    return [self initWithNodeID:nodeId ipAddressInt:ipAddressInt port:port];
}

-(DHTNode *)initWithNodeID:(NSData *)nodeId ipAddressString:(NSString *)ipAddress port:(uint16_t)port {
    NSArray *ipExplode = [ipAddress componentsSeparatedByString:@"."];
    int seg1 = [ipExplode[0] intValue];
    int seg2 = [ipExplode[1] intValue];
    int seg3 = [ipExplode[2] intValue];
    int seg4 = [ipExplode[3] intValue];
    
    uint32_t newIP = 0;
    newIP |= (uint32_t)((seg1 & 0xFF) << 24);
    newIP |= (uint32_t)((seg2 & 0xFF) << 16);
    newIP |= (uint32_t)((seg3 & 0xFF) << 8);
    newIP |= (uint32_t)((seg4 & 0xFF) << 0);

    return [self initWithNodeID:nodeId ipAddressInt:newIP port:port];
}

-(DHTNode *)initWithNodeID:(NSData *)nodeId ipAddressInt:(uint32_t)ipAddress port:(uint16_t)port {
    if (self = [self init]) {
        _nodeId = nodeId;
        _ipAddress = ipAddress;
        _port = port;
        if (!_nodeId) {
            NSError *error;
            _nodeId = [NARandom randomData:20 error:&error];
        }
    }
    return self;
}

-(void) startPingTimer {
    self.pingTimer = [GCDTimer scheduledTimerWithTimeInterval:900.0 repeats:YES block:^{
        if (self.pingAttempts <= 2) {
            if (self.pingAttempts == 2) {
                self.pingState = DHTNodeStateQuestionable;
            }
            [self ping];
        } else {
            self.pingState = DHTNodeStateBad;
            [self stopPingTimer];
        }
    }];
}

-(void) stopPingTimer {
    if (self.pingTimer) {
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }
}

#pragma mark - Routing
-(void)addNode:(DHTNode *)node {
    // Check if this is the bootstrap node
    if ([self.buckets count] == 1 && [self.buckets[0] count] == 0) {
        NSMutableArray *bucket = [self.buckets[0] mutableCopy];
        [bucket addObject:node];
        self.buckets = bucket;
        [node findNodeWithNodeID:self.nodeId];
    }
}

-(void)removeNode:(DHTNode *)node {
    
}

#pragma mark - Requests
// Ping
-(void)ping {
    self.pingAttempts++;
    NSDictionary *request = @{@"y" : @"q", // This is a query,
                              @"q" : PING,
                              @"t" : [self getTransactionIdForQueryType:PING],
                              @"a" : @{@"id" : self.nodeId}};
    
    [self.transportManager sendMessage:[BEncoding encodeObject:request] toHost:self.ipAddressString toPort:self.port];
}

// get_peers
-(void)getPeersForInfoHash:(NSData *)infoHash {
    
    
    NSDictionary *request = @{@"y" : @"q", // This is a query,
                              @"q" : GET_PEERS,
                              @"t" : [self getTransactionIdForQueryType:GET_PEERS],
                              @"a" : @{@"id" : self.nodeId,
                                       @"info_hash" : infoHash}};
    
    [self.transportManager sendMessage:[BEncoding encodeObject:request] toHost:self.ipAddressString toPort:self.port];
}

-(void)announcePeerForInfoHash:(NSData *)infoHash {
    [self announcePeerForInfoHash:infoHash port:0];
}

// announce_peer
-(void)announcePeerForInfoHash:(NSData *)infoHash port:(NSUInteger)port {
    [self getPeersForInfoHash:infoHash];
    
    NSDictionary *request = @{@"y" : @"q", // This is a query,
                              @"q" : ANNOUNCE_PEER,
                              @"t" : [self getTransactionIdForQueryType:ANNOUNCE_PEER],
                              @"a" : @{@"id" : self.nodeId,
                                       @"implied_port" : port == 0 ? @(1) : @(0), // forget our port and get udp source
                                       @"info_hash" : infoHash,
                                       @"port" : @(port),
                                       @"token" : @"<opaque token>"}};
    
    [self.transportManager sendMessage:[BEncoding encodeObject:request] toHost:self.ipAddressString toPort:self.port];
}

// find_node
-(void)findNodeWithNodeID:(NSData *)nodeId {
    NSDictionary *request = @{@"y" : @"q", // This is a query,
                              @"q" : FIND_NODE,
                              @"t" : [self getTransactionIdForQueryType:FIND_NODE],
                              @"a" : @{@"id" : self.nodeId,
                                       @"target" : nodeId}};
    
    // If we are addressing ourself, there is no need for real transport
    if ([nodeId isEqual:self.nodeId]) {
        return [self handleIncomingFindNode:request fromHost:self.ipAddressString fromPort:self.port];
    }
    
    [self.transportManager sendMessage:[BEncoding encodeObject:request] toHost:self.ipAddressString toPort:self.port];
}

#pragma mark - Response Handlers
-(void)pingResponse:(NSDictionary *)response {
    if (response[@"a"][@"id"] && response[@"a"][@"id"] == self.nodeId) {
        self.pingState = DHTNodeStateGood;
        self.lastSeen = [NSDate new];
    }
}

-(void)findNodeResponse:(NSDictionary *)response {
    
}

-(void)announcePeerResponse:(NSDictionary *)response {
    
}

-(void)getPeersResponse:(NSDictionary *)response {
    
}


#pragma mark - Incoming Request Handlers
-(void)handleIncomingPing:(NSDictionary *)request fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    // Do request error checking
    if (!request[@"t"] ||
        !request[@"a"] ||
        !request[@"a"][@"id"]) {
        return [self sendError:DHTKRPCErrCodeProtocolError fromHost:fromHost fromPort:fromPort];
    }
    
    NSDictionary *messageDict = @{@"y" : @"r",
                                  @"t" : request[@"t"], // Send back the transaction id
                                  @"r" : @{@"id": self.nodeId}};
    
    [self.transportManager sendMessage:[BEncoding encodeObject:messageDict] toHost:fromHost toPort:fromPort];
}


-(void)handleIncomingAnnouncePeer:(NSDictionary *)request fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    // Do request error checking
    if (!request[@"t"] ||
        !request[@"a"] ||
        !request[@"a"][@"id"] ||
        !request[@"a"][@"info_hash"] ||
        !request[@"a"][@"token"] ||
        !request[@"a"][@"port"]) {
        return [self sendError:DHTKRPCErrCodeProtocolError fromHost:fromHost fromPort:fromPort];
    }
    
    NSData *infoHashData = request[@"a"][@"info_hash"];
    NSString *infoHashString = [infoHashData na_hexString];
    NSString *token = request[@"a"][@"token"];
    NSDictionary *tokenIssueRequest = self.issuedTokens[token];
    if (!tokenIssueRequest) {
        return [self sendError:DHTKRPCErrCodeProtocolError fromHost:fromHost fromPort:fromPort];
    }
    NSDate *tokenIssueTime = tokenIssueRequest[@"issued_on"];
    NSString *issuedIpAddress = tokenIssueRequest[@"ip_address"];
    if (!tokenIssueTime ||
        !issuedIpAddress) {
        return [self sendError:DHTKRPCErrCodeProtocolError fromHost:fromHost fromPort:fromPort];
    }
    if (![issuedIpAddress isEqualToString:fromHost]) {
        return [self sendError:DHTKRPCErrCodeProtocolError fromHost:fromHost fromPort:fromPort];
    }

    
    // Build the incoming peer contact info
    NSMutableData *peerContactInfo = [NSMutableData new];
    uint32_t ipAddressInt = [self ipAddressToInt:fromHost];
    uint16_t port = 0;
    // If an implied_port is requested then we need to take the incoming UDP port
    if (request[@"a"][@"implied_port"] &&
        [request[@"a"][@"implied_port"] unsignedIntValue] == 1) {
        port = fromPort;
    } else {
        port = [request[@"a"][@"port"] unsignedIntValue];
    }
    [peerContactInfo appendBytes:&ipAddressInt length:4];
    [peerContactInfo appendBytes:&port length:2];
    
    // Check whether the peer contact info already exists for this infoHash
    NSMutableArray *peerContactArray  = self.issuedTokens[infoHashString] ? [self.issuedTokens[infoHashString] mutableCopy] : [NSMutableArray new];
    if (![peerContactArray containsObject:peerContactInfo]) {
        [peerContactArray addObject:peerContactInfo];
    }
    [self.infoHashes setObject:peerContactArray forKey:infoHashString];
    
    NSDictionary *messageDict = @{@"y" : @"r",
                                  @"t" : request[@"t"], // Send back the transaction id
                                  @"r" : @{@"id": self.nodeId}};
    
    [self.transportManager sendMessage:[BEncoding encodeObject:messageDict] toHost:fromHost toPort:fromPort];
}

-(void)handleIncomingGetPeers:(NSDictionary *)request fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    // response: {"id" : "<queried nodes id>", "token" :"<opaque write token>", "values" : ["<peer 1 info string>", "<peer 2 info string>"]}
    
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:@{@"id" : self.nodeId,  @"token" : [self.tokens lastObject]}];
    
    NSArray *infoHashValues = [self.peerContactInfo objectForKey:request[@"a"][@"info_hash"]];
    if (infoHashValues) {
        response[@"values"] = infoHashValues;
    } else {
        NSMutableArray *peerInfoStrings = [NSMutableArray new];
        for (DHTNode *node in [self getClosestNodesForInfoHash:request[@"a"][@"info_hash"]]) {
            [peerInfoStrings addObject:[node compactNodeInfo]];
        }
        response[@"nodes"] = peerInfoStrings;
    }
    
    NSDictionary *messageDict = @{@"y" : @"r", // This is a query,
                                  @"t" : request[@"t"],
                                  @"r" : response
                                  };
    
    [self.transportManager sendMessage:[BEncoding encodeObject:messageDict] toHost:fromHost toPort:fromPort];
}

-(void)handleIncomingFindNode:(NSDictionary *)request fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    //response: {"id" : "<queried nodes id>", "nodes" : "<compact node info>"}
    
    NSDictionary *messageDict = @{@"y" : @"r", // This is a query,
                                  @"t" : request[@"t"],
                                  @"r" : @{@"nodes" : [self getClosestNodesForNodeID:request[@"a"][@"target"] numberOfNodes:8]}};
    [self.transportManager sendMessage:[BEncoding encodeObject:messageDict] toHost:fromHost toPort:fromPort];
}

// error
-(void)sendError:(DHTKRPCErrCode)errorCode fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    [self sendError:errorCode transactionId:nil fromHost:fromHost fromPort:fromPort];
}

-(void)sendError:(DHTKRPCErrCode)errorCode transactionId:(NSString *)transactionId fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    switch (errorCode) {
        case DHTKRPCErrCodeGenericError:
            [self sendError:errorCode description:@"A Generic Error Ocurred" transactionId:transactionId fromHost:fromHost fromPort:fromPort];
            break;
        case DHTKRPCErrCodeServerError:
            [self sendError:errorCode description:@"A Server Error Ocurred" transactionId:transactionId fromHost:fromHost fromPort:fromPort];
            break;
        case DHTKRPCErrCodeProtocolError:
            [self sendError:errorCode description:@"A Protocol Error Occured, such as a malformed packet, invalid arguments, or bad token" transactionId:transactionId fromHost:fromHost fromPort:fromPort];
            break;
        case DHTKRPCErrCodeMethodUknown:
            [self sendError:errorCode description:@"A Method Uknown Error Ocurred" transactionId:transactionId fromHost:fromHost fromPort:fromPort];
            break;
        default:
            [self sendError:errorCode description:@"A Generic Error Ocurred" transactionId:transactionId fromHost:fromHost fromPort:fromPort];
            break;
    }
}

-(void)sendError:(DHTKRPCErrCode)errorCode description:(NSString *)description transactionId:(NSString *)transactionId fromHost:(NSString *)fromHost fromPort:(NSUInteger)fromPort {
    NSDictionary *messageDict = @{@"y" : @"e",
                                  @"t" : (transactionId && [transactionId length] == 2) ? transactionId : @"aa",
                                  @"e" : @[@(errorCode), description]};
    
    [self.transportManager sendMessage:[BEncoding encodeObject:messageDict] toHost:fromHost toPort:fromPort];
}

-(void)handleIncomingData:(NSData *)data fromHost:(NSString *)fromHost fromPort:(uint16_t)fromPort {
    NSDictionary *incomingDict = [BEncoding bdecodeDict:[[BData alloc] initWithData:data]];
    
    if (!incomingDict[@"y"] || (!incomingDict[@"q"] && ([incomingDict[@"y"] isEqualToString:@"q"])) || !incomingDict[@"t"]) {
        return [self sendError:DHTKRPCErrCodeProtocolError description:@"Invalid q argument" transactionId:incomingDict[@"t"] fromHost:fromHost fromPort:fromPort];
    }
    
    // Handle incoming requests
    if ([incomingDict[@"y"] isEqualToString:@"q"]) {
        if ([incomingDict[@"q"] isEqualToString:FIND_NODE]) {
            return [self handleIncomingFindNode:incomingDict fromHost:fromHost fromPort:fromPort];
        } else if ([incomingDict[@"q"] isEqualToString:ANNOUNCE_PEER])  {
            return [self handleIncomingAnnouncePeer:incomingDict fromHost:fromHost fromPort:fromPort];
        } else if ([incomingDict[@"q"] isEqualToString:GET_PEERS])  {
            return [self handleIncomingGetPeers:incomingDict fromHost:fromHost fromPort:fromPort];
        }
    // Handle incoming responses
    } else if ([incomingDict[@"y"] isEqualToString:@"r"]) {
        NSDictionary *txDict = [self.transactionIdsUsed objectForKey:incomingDict[@"t"]];
        NSString *method = txDict ? txDict[@"type"] : nil;
        NSDate *queryTime = txDict ? txDict[@"time"] : nil;
        if (!txDict || !method || !queryTime) {
            return [self sendError:DHTKRPCErrCodeProtocolError transactionId:incomingDict[@"t"] fromHost:fromHost fromPort:fromPort];
        }
        NSTimeInterval secondsBetweenDates = [[NSDate new] timeIntervalSinceDate:queryTime];
        if (secondsBetweenDates > 30) {
            self.pingState = DHTNodeStateQuestionable;
            return [self sendError:DHTKRPCErrCodeProtocolError fromHost:fromHost fromPort:fromPort];
        }
        
        if ([method isEqualToString:PING]) {
            return [self pingResponse:incomingDict];
        } else if ([method isEqualToString:ANNOUNCE_PEER]) {
            return [self announcePeerResponse:incomingDict];
        } else if ([method isEqualToString:GET_PEERS]) {
            return [self getPeersResponse:incomingDict];
        } else if ([method isEqualToString:FIND_NODE]) {
            return [self findNodeResponse:incomingDict];
        }
    }
    
    return [self sendError:DHTKRPCErrCodeMethodUknown transactionId:incomingDict[@"t"] fromHost:fromHost fromPort:fromPort];
}

// Compact node info
-(NSData *)nodeContactInfo {
    NSMutableData *data = [NSMutableData dataWithData:self.nodeId];
    [data appendData:[self peerContactInfo]];
    return data;
}

// Compact IP-address/port peer info
-(NSData *)peerContactInfo {
    NSMutableData *data = [NSMutableData new];
    [data appendBytes:&_ipAddress length:4];
    [data appendBytes:&_port length:2];
    return data;
}

// String representation of nodeId
-(NSString *)nodeIdString {
    return [self.nodeId na_hexString];
}

-(NSString *)ipAddressString {
    return [NSString stringWithFormat:@"%u.%u.%u.%u",
                          ((self.ipAddress >> 24) & 0xFF),
                          ((self.ipAddress >> 16) & 0xFF),
                          ((self.ipAddress >> 8) & 0xFF),
                          ((self.ipAddress >> 0) & 0xFF)];
}

-(DHTNodeState)pingState {
    @synchronized(self) {
        return pingState;
    }
}

-(void)setPingState:(DHTNodeState)newState {
    @synchronized(self) {
        pingState = newState;
    }
    [self.delegate dhtNode:self didChangeState:newState];
}

-(NSData *)distanceFromOtherNode:(DHTNode *)otherNode {
    NSMutableData *outputData = [NSMutableData dataWithData:self.nodeId];
    [outputData na_XORWithData:otherNode.nodeId index:[self.nodeId length]];
    return outputData;
}

-(NSData *)hashData:(NSData *)data {
    return [NADigest digestForData:data algorithm:NADigestAlgorithmSHA1];
}

-(uint32_t)ipAddressToInt:(NSString *)ipAddress {
    NSArray *ipExplode = [ipAddress componentsSeparatedByString:@"."];
    int seg1 = [ipExplode[0] intValue];
    int seg2 = [ipExplode[1] intValue];
    int seg3 = [ipExplode[2] intValue];
    int seg4 = [ipExplode[3] intValue];
    
    uint32_t newIP = 0;
    newIP |= (uint32_t)((seg1 & 0xFF) << 24);
    newIP |= (uint32_t)((seg2 & 0xFF) << 16);
    newIP |= (uint32_t)((seg3 & 0xFF) << 8);
    newIP |= (uint32_t)((seg4 & 0xFF) << 0);
    
    return newIP;
}

-(NSString *)getTransactionIdForQueryType:(NSString *)queryType {
    if (!self.lastTransactionId || [self.lastTransactionId length] == 0 || [self.lastTransactionId isEqualToString:@"zz"]) {
        self.lastTransactionId = @"aa";
    } else {
        self.lastTransactionId = [self incrementTXID:self.lastTransactionId];
    }
    [self.transactionIdsUsed setObject:@{@"type": queryType, @"time": [NSDate new]} forKey:self.lastTransactionId];
    
    return self.lastTransactionId;
}

-(NSString *)incrementTXID:(NSString *)txId {
    const unichar z = 0x007A;
    
    NSUInteger length = [txId length];
    unichar aBuffer[length];
    
    [txId getCharacters:aBuffer range:NSMakeRange(0, length)];
    
    if (aBuffer[0] != z) {
        aBuffer[0]++;
    } else if (aBuffer[1] != z) {
        aBuffer[1]++;
    }
    return [NSString stringWithCharacters:aBuffer length:length];
}

@end
