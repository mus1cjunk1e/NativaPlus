//
//  NSString+Host.m
//  Nativa
//
//  Created by Vladimir Solomenchuk on 12.07.10.
//  Copyright 2010 aramzamzam.net. All rights reserved.
//

#import "NIHostPort.h"


@implementation NIHostPort
@synthesize host, port;

+(id) parseHostPort:(NSString *) hostPort defaultPort:(int) defaultPort;
{
    NSString *trimmed =
    [hostPort stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSArray *parsed = [trimmed componentsSeparatedByString: @":"];
    
    NIHostPort *result = [[NIHostPort alloc] init];
    result.host = [parsed objectAtIndex:0];
	result.port = [parsed count]>1?[[parsed objectAtIndex:1] intValue]:defaultPort;
    
    return [result autorelease];
}

@end
