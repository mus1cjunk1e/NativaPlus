//
//  NSString+Host.h
//  Nativa
//
//  Created by Vladimir Solomenchuk on 12.07.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NIHostPort:NSObject
{
    NSString *host;
    int      port;
}
@property (retain) NSString *host;
@property (assign) int      port;
+(id) parseHostPort:(NSString *) hostPort defaultPort:(int) defaultPort;
@end