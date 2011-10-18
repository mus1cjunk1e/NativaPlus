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

#import "RTConnection.h"
#import "AMSession.h"

static NSString* ProxyConnectedContext = @"ProxyConnectedContext";


@implementation RTConnection

@synthesize connected = _connected;
@synthesize connecting = _connecting;
@dynamic error;

- (id)initWithHostPort:(NSString *)initHost port:(int)initPort proxy:(AMSession*) proxy;
{
	hostName = [initHost retain];
	port = initPort;
	_connecting = NO;
	_connected = NO;
    _proxy = [proxy retain];
	return self;
}


- (BOOL) openStreams:(NSInputStream **)iStream oStream:(NSOutputStream **) oStream delegate:(id) delegate error:(NSString **) connectionError
{
	if (!_connected)
    {
		*connectionError = [NSString stringWithString:@"Not connected"];
        return NO;
    }
	NSHost *host = [NSHost hostWithAddress:hostName];
	if (host != nil)
	{
		[NSStream getStreamsToHost:host 
							  port:(_proxy==nil?port:[_proxy localPort]) 
						inputStream:iStream
					   outputStream:oStream];
		
		[(*iStream) scheduleInRunLoop:[NSRunLoop currentRunLoop]
						   forMode:NSDefaultRunLoopMode];
		(*iStream).delegate = delegate;
		
		[(*oStream) scheduleInRunLoop:[NSRunLoop currentRunLoop]
						   forMode:NSDefaultRunLoopMode];
		(*oStream).delegate = delegate;
		
		[(*oStream) open];
		[(*iStream) open];
		return YES;
	}
    *connectionError = [NSString stringWithFormat:@"Unable to resolve host: %@",hostName];
	return NO;
}

-(void) closeConnection
{
    [self willChangeValueForKey:@"connecting"];
    [self willChangeValueForKey:@"connected"];
    _connected = NO;
    _connecting = NO;
    [self didChangeValueForKey:@"connecting"];
    [self didChangeValueForKey:@"connected"];
    
    if (_proxy != nil) 
    {
        @try {
            [_proxy removeObserver:self forKeyPath:@"connected"];
        }
        @catch (NSException *exception) {
                //ignore objserver removal exception
        }
        [_proxy closeTunnel];
    }
    [self setError:nil];
}

-(void) openConnection:(void (^)(RTConnection *sender))handler
{
    if (hostName == nil || [hostName isEqualToString:@""]) 
    {
        [self setError:@"SCGI host cannot be empty"];
        if (handler)
            handler(self);
        return;
    }
    
	if (_proxy == nil)
	{
		[self willChangeValueForKey:@"connecting"];
		[self willChangeValueForKey:@"connected"];
		_connected = YES;
		_connecting = NO;
		[self didChangeValueForKey:@"connecting"];
		[self didChangeValueForKey:@"connected"];
        if (handler != nil) 
            handler(self);
	}
	else
	{
        [_proxy addObserver:self
                     forKeyPath:@"connected"
                        options:0
                        context:&ProxyConnectedContext];
		[_proxy openTunnel:^(AMSession *sender){
            if (handler != nil) 
                handler(self);
        }];
	}
}

-(void)dealloc;
{
	[hostName release];
	[_proxy release];
    [self setError:nil];
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &ProxyConnectedContext)
    {
		[self willChangeValueForKey:@"connecting"];
		[self willChangeValueForKey:@"connected"];
		_connected = _proxy.connected;
		_connecting =_proxy.connecting;
		[self didChangeValueForKey:@"connected"];
		[self didChangeValueForKey:@"connecting"];
    }
    
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

-(void) setError:(NSString *) err
{
    if (err == error) 
        return;
    [err release];
    error = [err retain];
}

-(NSString*)error
{
    if (error != nil)
        return error;
    if (_proxy != nil)
        return _proxy.error;
    return nil;
}
@end
