/******************************************************************************
 * Nativa - MacOS X UI for rtorrent
 * http://www.aramzamzam.net
 *
 * Copyright Solomenchuk V. 2010.
 * Solomenchuk Vladimir <vovasty@aramzamzam.net>
 *
 * Licensed under the GPL, Version 3.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.gnu.org/licenses/gpl-3.0.html
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/

#import "ProcessesController.h"
#import "SynthesizeSingleton.h"
#import "PreferencesController.h"
#import "AMSession.h"
#import "AMServer.h"
#import "RTConnection.h"
#import "RTorrentController.h"
#import "EMKeychainItem.h"


@interface ProcessesController(Private)
-(NSMutableDictionary *) dictionaryForIndex:(NSInteger) index;
-(void) setObject:(id) object forKey:(NSString *) key forIndex:(NSInteger) index;
-(id) object:(NSString *) key forIndex:(NSInteger) index;
@end

@implementation ProcessesController
SYNTHESIZE_SINGLETON_FOR_CLASS(ProcessesController);

- (id) init
{
    if ((self = [super init]))
    {
		NSArray* procs;
		
		_processes = [[NSMutableArray alloc] init];
		
		if ((procs = [[NSUserDefaults standardUserDefaults] arrayForKey: @"Processes"]))
		{
			for (NSDictionary * dict in procs)
			{
				NSMutableDictionary * tempDict = [dict mutableCopy];
				
				//retrieve SSH password from keychain
				if ([[tempDict objectForKey:@"ConnectionType"] isEqualToString:@"SSH"] && ![[tempDict objectForKey:@"SSHUseKeyLogin"] boolValue])
				{
					EMInternetKeychainItem *keychainItem = [EMInternetKeychainItem internetKeychainItemForServer:[tempDict objectForKey:@"SSHHost"]
																									withUsername:[tempDict objectForKey:@"SSHUser"]
																											path:nil
																											port:[[tempDict objectForKey:@"SSHPort"] integerValue] 
																										protocol:kSecProtocolTypeSSH];
				
					[tempDict setObject:keychainItem.password==nil?@"":keychainItem.password forKey:@"SSHPassword"];
				}
				
				[_processes addObject:tempDict];
				[tempDict release];
			}
		}
    }
    
    return self;
}

- (void) dealloc
{
	[_processes release];
    [super dealloc];
}


-(NSInteger) count
{
	return [_processes count];
}

- (void) saveProcesses
{
    NSMutableArray * processes = [NSMutableArray arrayWithCapacity: [_processes count]];
    for (NSDictionary * dict in _processes)
    {
        NSMutableDictionary * tempDict = [dict mutableCopy];
		//don't archive the ProcessObject
        [tempDict removeObjectForKey: @"ProcessObject"];

		
		//store SSH password in keychain
		if ([[tempDict objectForKey:@"ConnectionType"] isEqualToString:@"SSH"] && ![[tempDict objectForKey:@"SSHUseKeyLogin"] boolValue])
		{
			NSString *password = [tempDict objectForKey:@"SSHPassword"];
			if (password !=nil && ![password isEqualToString:@""])
			{
				EMInternetKeychainItem *keychainItem = [EMInternetKeychainItem addInternetKeychainItemForServer:[tempDict objectForKey:@"SSHHost"]
														withUsername:[tempDict objectForKey:@"SSHUser"]
															password:password
																path:nil
																port:[[tempDict objectForKey:@"SSHPort"] integerValue]
															protocol:kSecProtocolTypeSSH];
				if (keychainItem == nil)
				{
					keychainItem = [EMInternetKeychainItem internetKeychainItemForServer:[tempDict objectForKey:@"SSHHost"]
																			withUsername:[tempDict objectForKey:@"SSHUser"]
																					path:nil
																					port:[[tempDict objectForKey:@"SSHPort"] integerValue] 
																				protocol:kSecProtocolTypeSSH];
					keychainItem.password = password;
				}
			}
			[tempDict removeObjectForKey: @"SSHPassword"];
		}
        [processes addObject: tempDict];
		
        [tempDict release];
    }
    
	[[NSUserDefaults standardUserDefaults] setObject: processes forKey: @"Processes"];
	
}


-(void) setName:(NSString *)name forIndex:(NSInteger) index
{
	[self setObject:name forKey:@"Name" forIndex:index];
	
}
-(NSString *) nameForIndex:(NSInteger) index
{
	return [self object:@"Name" forIndex:index];
}

-(void) setProcessType:(NSString *)type forIndex:(NSInteger) index
{
	[self setObject:type forKey:@"ProcessType" forIndex:index];
}

-(NSString *) processTypeForIndex:(NSInteger) index
{
	return [self object:@"ProcessType" forIndex:index];
}

-(void) setConnectionType:(NSString *)type forIndex:(NSInteger) index
{
	[self setObject:type forKey:@"ConnectionType" forIndex:index];
}

-(NSString *) connectionTypeForIndex:(NSInteger) index
{
	return [self object:@"ConnectionType" forIndex:index];
}

-(void) setHost:(NSString *)host forIndex:(NSInteger) index
{
	[self setObject:host forKey:@"Host" forIndex:index];
}

-(NSString *) hostForIndex:(NSInteger) index
{
	return [self object:@"Host" forIndex:index];
}

-(void) setPort:(NSInteger)port forIndex:(NSInteger) index
{
	[self setObject:[NSNumber numberWithInteger:port] forKey:@"Port" forIndex:index];
}
-(NSInteger) portForIndex:(NSInteger) index
{
	return [[self object:@"Port" forIndex:index] intValue];
}

-(void) setLocalDownloadsFolder:(NSString *)folder forIndex:(NSInteger) index
{
	[self setObject:folder forKey:@"LocalDownloadsFolder" forIndex:index];
}

-(NSString *) localDownloadsFolderForIndex:(NSInteger) index
{
	return [self object:@"LocalDownloadsFolder" forIndex:index];
}

-(void) setSshHost:(NSString *)host forIndex:(NSInteger) index
{
	[self setObject:host forKey:@"SSHHost" forIndex:index];
}

-(NSString *) sshHostForIndex:(NSInteger) index
{
	return [self object:@"SSHHost" forIndex:index];
}

-(void) setSshPort:(NSInteger)port forIndex:(NSInteger) index
{
	[self setObject:[NSNumber numberWithInteger:port] forKey:@"SSHPort" forIndex:index];
}

-(NSInteger) sshPortForIndex:(NSInteger) index
{
	return [[self object:@"SSHPort" forIndex:index] intValue];
}

-(void) setSshLocalPort:(NSInteger)port forIndex:(NSInteger) index
{
	[self setObject:[NSNumber numberWithInteger:port] forKey:@"SSHLocalPort" forIndex:index];
}

-(NSInteger) sshLocalPortForIndex:(NSInteger) index
{
	return [[self object:@"SSHLocalPort" forIndex:index] intValue];
}

-(void) setSshUser:(NSString *)user forIndex:(NSInteger) index
{
	[self setObject:user forKey:@"SSHUser" forIndex:index];
}

-(NSString *) sshUserForIndex:(NSInteger) index
{
	return [self object:@"SSHUser" forIndex:index];
}

-(void) setSshPassword:(NSString *)password forIndex:(NSInteger) index
{
    if (password == nil)
    {
        NSMutableDictionary* dict = [self dictionaryForIndex:index];
        [dict removeObjectForKey: @"SSHPassword"];    
    }
    else
        [self setObject:password forKey:@"SSHPassword" forIndex:index];
}
-(NSString *) sshPasswordForIndex:(NSInteger) index
{
	return [self sshUseKeyLoginForIndex:index]?@"":[self object:@"SSHPassword" forIndex:index];
}

-(void) setMaxReconnects:(NSInteger)maxReconnects forIndex:(NSInteger) index
{
	[self setObject:[NSNumber numberWithInteger:maxReconnects] forKey:@"MaxReconnects" forIndex:index];
}

-(NSInteger) maxReconnectsForIndex:(NSInteger) index
{
	return [[self object:@"MaxReconnects" forIndex:index] intValue];
}

-(void) setGroupsField:(NSInteger)groupsField forIndex:(NSInteger) index
{
	[self setObject:[NSNumber numberWithInteger:groupsField] forKey:@"GroupsField" forIndex:index];
}

-(NSInteger) groupsFieldForIndex:(NSInteger) index
{
	return [[self object:@"GroupsField" forIndex:index] intValue];
}

-(void) setSshUseKeyLogin:(BOOL)sshUseKeyLogin forIndex:(NSInteger) index;
{
	[self setObject:[NSNumber numberWithBool:sshUseKeyLogin] forKey:@"SSHUseKeyLogin" forIndex:index];
}

-(BOOL) sshUseKeyLoginForIndex:(NSInteger) index
{
	return [[self object:@"SSHUseKeyLogin" forIndex:index] boolValue];
}

-(void) setSshUseV2:(BOOL)sshUseV2 forIndex:(NSInteger) index;
{
	[self setObject:[NSNumber numberWithBool:sshUseV2] forKey:@"SSHUseV2" forIndex:index];
}
-(BOOL) sshUseV2ForIndex:(NSInteger) index
{
	return [[self object:@"SSHUseV2" forIndex:index] boolValue];
}


-(void) setSshCompressionLevel:(NSInteger)sshCompressionLevel forIndex:(NSInteger) index
{
	[self setObject:[NSNumber numberWithInteger:sshCompressionLevel] forKey:@"SSHCompressionLevel" forIndex:index];
}

-(NSInteger) sshCompressionLevelForIndex:(NSInteger) index
{
	return [[self object:@"SSHCompressionLevel" forIndex:index] intValue];
}

- (NSInteger) addProcess
{
    //find the lowest index
    NSInteger index;
    for (index = 0; index < [_processes count]; index++)
    {
        BOOL found = NO;
        for (NSDictionary * dict in _processes)
            if ([[dict objectForKey: @"Index"] integerValue] == index)
            {
                found = YES;
                break;
            }
        
        if (!found)
            break;
    }
    
    [_processes addObject: [NSMutableDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInteger: index], @"Index", [NSNumber numberWithInteger: 1], @"GroupsField", nil]];
	return index;
}

- (NSInteger) indexForRow: (NSInteger) row
{
    return [[[_processes objectAtIndex: row] objectForKey: @"Index"] integerValue];
}

-(void) openProcessForIndex:(NSInteger) index handler:(void (^)(NSString *error)) handler
{
    id<TorrentController> process = [self processForIndex:index];

    AMSession* proxy = nil;
    if ([[self connectionTypeForIndex:index] isEqualToString: @"SSH"])
    {
        proxy = [[AMSession alloc] init];
        proxy.sessionName = [self nameForIndex:index];
        proxy.remoteHost = [self hostForIndex:index];
        proxy.remotePort = [self portForIndex:index];
        
        proxy.localPort = [self sshLocalPortForIndex:index];
        
        AMServer *server = [[AMServer alloc] init];
        server.host = [self sshHostForIndex:index];
        server.username = [self sshUserForIndex:index];
        server.password = [self sshPasswordForIndex:index];
        server.port = [self sshPortForIndex:index];
        server.useSSHV2 = [self sshUseV2ForIndex:index];
        server.useSSHKeyLogin = [self sshUseKeyLoginForIndex:index];
        server.compressionLevel = [self sshCompressionLevelForIndex:index];
        proxy.currentServer = server;
        proxy.maxAutoReconnectRetries = [self maxReconnectsForIndex:index];
        proxy.autoReconnect = YES;
        [server release];
    }
    
    RTConnection* connection = [[RTConnection alloc] initWithHostPort:[self hostForIndex:index] port:[self portForIndex:index] proxy:proxy];
    
    [(RTorrentController*)process setConnection:connection];
    
    [connection release];
    [proxy release];
    
    [(RTorrentController *)process setGroupField: [self groupsFieldForIndex:index]];    
    
	[process openConnection: handler];
}

-(void) closeProcessForIndex:(NSInteger) index
{
	[[self object:@"ProcessObject" forIndex:index] closeConnection];
}

-(id<TorrentController>) processForIndex:(NSInteger) index
{
    id<TorrentController> process = [self object:@"ProcessObject" forIndex:index];
    if (process == nil)
    {
        process = [[RTorrentController alloc] init];
        
        [self setObject:process forKey:@"ProcessObject" forIndex:index];
        
        [process release];
    }
	return process;
}
@end

@implementation ProcessesController(Private)
-(NSMutableDictionary *) dictionaryForIndex:(NSInteger) index
{
	if (index != -1)
    {
        for (NSInteger i = 0; i < [_processes count]; i++)
		{
            NSMutableDictionary* dict = [_processes objectAtIndex: i];
			if (index == [[dict objectForKey: @"Index"] integerValue])
                return dict;
		}
    }
    return nil;
}

-(void) setObject:(id) object forKey:(NSString *) key forIndex:(NSInteger) index
{
	NSMutableDictionary* dict = [self dictionaryForIndex:index];
    if (object == nil)
        [dict removeObjectForKey:key];
    else
        [dict setObject:object forKey: key];
}

-(id) object:key forIndex:(NSInteger) index
{
	NSMutableDictionary* dict = [self dictionaryForIndex:index];
	return [dict objectForKey: key] ;
}
@end
