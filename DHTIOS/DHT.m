//
//  DHT.m
//  DHTIOS
//
//  Created by Andy on 8/9/14.
//  Copyright (c) 2014 Andy. All rights reserved.
//

#import "DHT.h"
#import "DHTNode.h"
#import "GCDTimer.h"
#import "SodiumObjc.h"
#import "NAChloride.h"
#import "M13OrderedDictionary.h"
#import "DHTTransportManager.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <arpa/inet.h>

@interface DHT()
@property (nonatomic, strong) M13MutableOrderedDictionary *routingTable;
@property (nonatomic, strong) NSMutableArray *tokens;
@property (nonatomic, strong) M13MutableOrderedDictionary *peerContactInfo;
@property (nonatomic, strong) GCDTimer *tokenSecretTimer;
@end

@implementation DHT

-(DHT *)init {
    if (self = [super init]) {
        self.routingTable = [[M13MutableOrderedDictionary alloc] init];
        
        // We change the token every 5 minutes
        self.tokenSecretTimer = [GCDTimer scheduledTimerWithTimeInterval:300.0 repeats:YES block:^{
            // Doesn't really matter what we add hereself.tokenSecret
            NSString *newSecret = [NSString stringWithFormat:@"%@%@%@", [self.rootNode ipAddressString], [NARandom randomData:32 error:nil], [NSDate new]];
            [self.tokens addObject:[[NADigest digestForData:[newSecret dataUsingEncoding:NSUTF8StringEncoding] algorithm:NADigestAlgorithmSHA1] na_hexString]];
            // We only ever want two secrets in the array
            if ([self.tokens count] > 2) {
                [self.tokens removeObjectsInRange:NSMakeRange(0, [self.tokens count] - 2)];
            }
        }];
    }
    return self;
}

-(DHT *)initWithBootstrapNodes:(NSArray *)nodes {
    if (self = [self init]) {
        for (DHTNode *node in nodes) {
            [self addNode:node];
        }
    }
    return self;
}

-(DHT *)initWithBootstrapServers:(NSArray *)servers {
    if (!servers || [servers count] == 0) {
        servers = @[@"router.bittorrent.com:6881"];
    }
    NSMutableArray *nodes = [NSMutableArray new];
    for (NSString *server in servers) {
        NSURL *url = [NSURL URLWithString:server];
        [nodes addObject:[[DHTNode alloc] initWithIpAddress:[self lookupHostIPAddressForURL:url] andPort:(uint16_t)url.port]];
    }
    if (self = [self initWithBootstrapNodes:nodes]) {
        
    }
    return self;
}

// Internal Methods
-(NSArray *)getClosestNodesForInfoHash:(NSString *)infoHash {
    return nil;
}

-(NSArray *)getClosestNodesForNodeID:(NSString *)nodeId numberOfNodes:(NSUInteger)numberOfNodes {
    return nil;
}
    
-(DHTNode *)getClosestNodeForNodeID:(NSData *)nodeId {
    for (DHTNode *node in self.routingTable) {
        // Loop through and compare nodeId with hash
    }
    return nil;
}

-(void)addNode:(DHTNode *)node {
    node.dhtManager = self;
    [self.routingTable addObject:node pairedWithKey:node.nodeId];
}

-(void)removeNodeWithID:(NSString *)nodeId {
    [self.routingTable removeObjectForKey:nodeId];
}

-(void)removeNode:(DHTNode *)node {
    [self.routingTable removeObjectForKey:node.nodeId];
}

-(NSString *)lookupHostIPAddressForURL:(NSURL *)url
{
    // Ask the unix subsytem to query the DNS
    struct hostent *remoteHostEnt = gethostbyname([[url host] UTF8String]);
    // Get address info from host entry
    struct in_addr *remoteInAddr = (struct in_addr *) remoteHostEnt->h_addr_list[0];
    // Convert numeric addr to ASCII string
    char *sRemoteInAddr = inet_ntoa(*remoteInAddr);
    // hostIP
    NSString* hostIP = [NSString stringWithUTF8String:sRemoteInAddr];
    return hostIP;
}

@end
