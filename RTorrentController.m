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

#import "RTorrentController.h"
#import "RTConnection.h"
#import "RTSCGIOperation.h"
#import "RTListCommand.h"
#import "NSStringRTorrentAdditions.h"

static NSString * ConnectedContext  = @"ConnectedContext";
static NSString * ConnectingContext = @"ConnectingContext";

@interface RTorrentController(Private)
-(void)_runOperation:(id<RTorrentCommand>) operation;
-(void)_runCommand:(NSString*) command arguments:(NSArray*)arguments handler:(void(^)(id data, NSString* error)) h;
-(void(^)(id data, NSString* error))_voidHandler:(VoidResponseBlock) handler;
@end

@implementation RTorrentController
@dynamic groupField;
@synthesize connection, connected, connecting;

- (id) init
{
    if ((self = [super init]) != nil)
    {
        _queue = [[NSOperationQueue alloc] init];
        [_queue setMaxConcurrentOperationCount:1];
        
        [_queue setSuspended:YES];
    }
    return self;
}

- (id)initWithConnection:(RTConnection*) conn;
{
	self = [super init];
	if (self == nil)
		return nil;
	
	[self setConnection:conn];
    _queue = [[NSOperationQueue alloc] init];
    [_queue setMaxConcurrentOperationCount:1];
    
    [_queue setSuspended:YES];
    
	
	return self;
}

-(void)dealloc;
{
	[_queue release];
	[self setConnection:nil];
	[_getGroupCommand release];
	[_setGroupCommand release];
    [self setConnection:nil];
	[super dealloc];
}

- (void) list:(ArrayResponseBlock) response;
{
	RTListCommand* command = [[RTListCommand alloc] initWithArrayResponse:response];
	[command setGroupCommand:_getGroupCommand];
	[self _runOperation: command];
	[command release];
}

- (void) start:(Torrent *)torrent handler:(VoidResponseBlock) handler
{
    __block RTorrentController *blockSelf = self;
    void(^r)(id data, NSString* error);
    r = [self _voidHandler:handler];
	[self _runCommand:@"d.open"
			 arguments:[NSArray arrayWithObjects:
						torrent.thash, 
						nil]
			  handler:^(id data, NSString* error){
                  if (error != nil)
                  {
                      r(data, error);
                      return;
                  }
                  [blockSelf _runCommand:@"d.start"
                          arguments:[NSArray arrayWithObjects:
                                     torrent.thash, 
                                     nil]
                            handler:r];
                  
              }];
	[r release];
}

- (void) stop:(Torrent *)torrent handler:(VoidResponseBlock) handler
{
    __block RTorrentController *blockSelf = self;
    void(^r)(id data, NSString* error);
    r = [self _voidHandler:handler];
	[self _runCommand:@"d.stop"
            arguments:[NSArray arrayWithObjects:
                       torrent.thash, 
                       nil]
			  handler:^(id data, NSString* error){
                  if (error != nil)
                  {
                      r(data, error);
                      return;
                  }
                  [blockSelf _runCommand:@"d.close"
                          arguments:[NSArray arrayWithObjects:
                                     torrent.thash, 
                                     nil]
                            handler:r];
                  
              }];
	[r release];
}

- (void) add:(NSData *)rawTorrent start:(BOOL) start group:(NSString*) group folder:(NSString*) folder response:(VoidResponseBlock) response
{
    NSString* command = start ? @"load_raw_start" : @"load_raw";
    NSMutableArray* args = [NSMutableArray arrayWithCapacity:3];
    
    [args addObject:rawTorrent];
    
    if (group != nil)
        [args addObject:[NSString stringWithFormat:@"%@=%@",_setGroupCommand,[group urlEncode]]];

    if (folder != nil)
        [args addObject:[NSString stringWithFormat:@"%@=%@",@"d.set_directory",folder]];

    id r = [self _voidHandler:response];

	[self _runCommand:command
			arguments:args
              handler:r];
	[r release];
    
}

- (void) erase:(NSString *)hash response:(VoidResponseBlock) response;
{
	id r = [self _voidHandler:response];
	[self _runCommand:@"d.erase"
			arguments:[NSArray arrayWithObjects:
					   hash, 
					   nil]
			 handler:r];
	[r release];
}

- (void) setGlobalDownloadSpeedLimit:(int) speed response:(VoidResponseBlock) response;
{
	id r = [self _voidHandler:response];
	[self _runCommand:@"set_download_rate"
			arguments:[NSArray arrayWithObjects:
					   [NSNumber numberWithInt:speed],
					   nil]
			 handler:r];
	[r release];
}

- (void) setGlobalUploadSpeedLimit:(int) speed response:(VoidResponseBlock) response;
{
	id r = [self _voidHandler:response];
	[self _runCommand:@"set_upload_rate"
			arguments:[NSArray arrayWithObjects:
					   [NSNumber numberWithInt:speed],
					   nil]
			 handler:r];
	[r release];
}

- (void) getGlobalDownloadSpeedLimit:(NumberResponseBlock) response
{
	[self _runCommand:@"get_download_rate"
			arguments:nil
			  handler:^(id data, NSString* error){
				  if (response)
					  response(data, error);
			  }];
}

- (void) getGlobalUploadSpeedLimit:(NumberResponseBlock) response
{
	[self _runCommand:@"get_upload_rate"
			arguments:nil
			  handler:^(id data, NSString* error){
				  if (response)
					  response(data, error);
			  }];
}

- (void) setPriority:(Torrent *)torrent  priority:(TorrentPriority)priority response:(VoidResponseBlock) response
{
	NSInteger pr;
	switch (priority) {
		case NITorrentPriorityLow:
			pr = 1;
			break;
		case NITorrentPriorityNormal:
			pr = 2;
			break;
		case NITorrentPriorityHigh:
			pr = 3;
			break;
		default:
			NSAssert1(NO, @"Unknown priority: %d", priority);
	}
	
	id r = [self _voidHandler:response];
	[self _runCommand:@"d.set_priority"
			arguments:[NSArray arrayWithObjects:
					   [torrent thash],
					   [NSNumber numberWithInteger:pr], 
					   nil]
			 handler:r];
	[r release];
}

- (void) setGroup:(Torrent *)torrent group:(NSString *) group response:(VoidResponseBlock) response
{
	id r = [self _voidHandler:response];
    NSString *gn = [group urlEncode];
	[self _runCommand:_setGroupCommand
			arguments:[NSArray arrayWithObjects:
					   torrent.thash,
					   gn==nil?@"":gn,
					   nil]
			 handler:r];
	[r release];
}

- (void) check:(Torrent *)torrent response:(VoidResponseBlock) response
{
	id r = [self _voidHandler:response];
	[self _runCommand:@"d.check_hash"
			arguments:[NSArray arrayWithObjects:
					   [torrent thash], 
					   nil]
			 handler:r];
	[r release];
}

- (void) pause:(Torrent *) torrent handler:(VoidResponseBlock) handler
{
	id r = [self _voidHandler:handler];
	[self _runCommand:@"d.stop"
            arguments:[NSArray arrayWithObjects:
                       torrent.thash, 
                       nil]
			  handler:r];
	[r release];
}

- (void) moveData:(Torrent *) torrent location:(NSString *) location handler:(VoidResponseBlock) handler
{
	id r = [self _voidHandler:handler];
	[self _runCommand:@"d.set_directory"
            arguments:[NSArray arrayWithObjects:
                       torrent.thash,
                       location,
                       nil]
			  handler:r];
	[r release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if (context == &ConnectedContext)
    {
		[_queue setSuspended:!connection.connected];
        [self setConnected:connection.connected];
    }
	else if (context == &ConnectingContext)
    {
        [self setConnecting:connection.connecting];
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

-(void) openConnection:(VoidResponseBlock) response;
{
    [connection addObserver:self
                 forKeyPath:@"connected"
                    options:0
                    context:&ConnectedContext];
    [connection addObserver:self
                 forKeyPath:@"connecting"
                    options:0
                    context:&ConnectingContext];
    connected = NO;
    connecting = NO;
	[connection openConnection:^(RTConnection *sender){
        if (response != nil)
            response([sender error]);
    }];
}

-(void) closeConnection
{
    @try {
        [connection removeObserver:self forKeyPath:@"connected"];
    }
    @catch (NSException *exception) {
            //ignore objserver removal exception
    }
    @try {
        [connection removeObserver:self forKeyPath:@"connecting"];
    }
    @catch (NSException *exception) {
            //ignore objserver removal exception
    }
	[connection closeConnection];
    [self willChangeValueForKey:@"connected"];
    [self willChangeValueForKey:@"connecting"];
    connected = NO;
    connecting = NO;
    [self didChangeValueForKey:@"connecting"];
    [self didChangeValueForKey:@"connected"];
}

-(NSUInteger) groupField;
{
	return _groupField;
}

-(void) setGroupField:(NSUInteger) value
{
	[_getGroupCommand release];
	_getGroupCommand = [NSString stringWithFormat:@"d.get_custom%@",[NSString stringWithFormat:@"%d", value]];
	[_getGroupCommand retain];
	[_setGroupCommand release];
	_setGroupCommand = [NSString stringWithFormat:@"d.set_custom%@",[NSString stringWithFormat:@"%d", value]];
	[_setGroupCommand retain];
	_groupField = value;
}

- (NSString *) lastError
{
    return [connection error];
}
@end

@implementation RTorrentController(Private)
-(void)_runOperation:(id<RTorrentCommand>) operation
{
	RTSCGIOperation* scgiOperation = [[RTSCGIOperation alloc] initWithOperation:self operation:operation];
	[_queue addOperation:scgiOperation];
	[scgiOperation release];
}

-(void)_runCommand:(NSString*) command arguments:(NSArray*)arguments handler:(void(^)(id data, NSString* error)) h
{
	RTSCGIOperation* scgiOperation = [[RTSCGIOperation alloc] initWithCommand:self command:command arguments:arguments handler:h];
	[_queue addOperation:scgiOperation];
	[scgiOperation release];
}

-(void(^)(id data, NSString* error))_voidHandler:(VoidResponseBlock) handler;
{
	return [^(id data, NSString* error){
		if (handler)
			handler(error);
	}copy];
}
@end