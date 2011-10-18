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

#import "RTSCGIOperation.h"
#import "RTorrentController.h"
#import "RTConnection.h"
#import "XMLRPCEncoder.h"
#import "XMLRPCTreeBasedParser.h"
#import "NSStringSCGIAdditions.h"

//#define MAX_RESPONSE_SIZE 524288
#define MAX_RESPONSE_SIZE 10485760

@interface RTSCGIOperation ()
- (void) requestDidSent;

- (void) responseDidReceived;

- (void) setError:(NSString*) error;

- (void) finish;

- (void) runResponse:(NSData*) data error:(NSString*) error;

- (NSArray*) arguments;

- (void) setArguments:(NSArray *) value;

- (NSString*) command;

- (void) setCommand:(NSString *) value;

@property (nonatomic, assign) NSAutoreleasePool       *pool;
@property (retain) RTorrentController                 *controller;
@property (retain) id<RTorrentCommand>                operation;
@end


@implementation RTSCGIOperation

@synthesize pool, handler, controller, operation;

- (id)initWithCommand:(RTorrentController *)control command:(NSString*)cmd arguments:(NSArray*)args handler:(void(^)(id data, NSString* error)) h;
{
	if (self = [super init])
	{
        [self setController: control];
        [self setOperation: nil];
		[self setArguments: args];
        [self setCommand: cmd];
		[self setHandler: h];
	}
	return self;
	
}

- (id)initWithOperation:(RTorrentController *)control operation:(id<RTorrentCommand>) oper;
{
	if (self = [super init])
	{
        [self setController: control];
        [self setOperation: oper];
        [self setCommand: nil];
		[self setArguments: nil];
	}
	return self;
}

- (void)main;
{
	self.pool = [[NSAutoreleasePool alloc] init];
    _isExecuting = YES;
	
	oStream = nil;
	iStream = nil;
	
	XMLRPCEncoder* xmlrpc_request = [[XMLRPCEncoder alloc] init];

	[xmlrpc_request setMethod:[self command] withParameters:[self arguments]];
	
	NSString* scgi_req = [xmlrpc_request encode];
	
	[xmlrpc_request release];
	_writtenBytesCounter = 0;
//	NSLog(@"request: %@", scgi_req);
	_requestData = [scgi_req encodeSCGI];
	[_requestData retain];
	
    NSString *error;
    
	if ([controller.connection openStreams:&iStream oStream:&oStream delegate:self error:&error])
	{
		[iStream retain];
		[oStream retain];
		time_t startTime = time(NULL) * 1000;
		time_t timeout = 1000;
		do {
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
			if ((time(NULL) * 1000 - startTime)>timeout)
			{
				if (_isExecuting)
                    [self setError:NSLocalizedString(@"Network timeout", "Network -> error")];
				break;
			}
		} while (_isExecuting);
	
	}
	else
		[self setError:error];

	[pool release];
    self.pool = nil;	
}


- (void)dealloc
{
	[_responseData release];
	[self setCommand: nil];
	[self setArguments: nil];
	[self setHandler: nil];
	[self setOperation:nil];
    [self setController:nil];
	[_requestData release];
	[super dealloc];
}

- (void) setArguments:(NSArray *) value
{
    if (arguments == value)
        return;
    [arguments release];
    arguments = [value retain];
}

- (NSArray*) arguments
{
	return operation==nil?arguments:[operation arguments];
}

-(void) setCommand:(NSString *) value
{
    if (command == value)
        return;
    [command release];
    command = [value retain];    
}

- (NSString*) command
{
	return operation==nil?command:[operation command];
}

- (void) requestDidSent;
{
    if (oStream != nil) 
	{
		oStream.delegate = nil;
        [oStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [oStream close];
		[oStream release];
        oStream = nil;
    }
}

- (void) responseDidReceived;
{
    if (iStream != nil) 
	{
		iStream.delegate = nil;
        [iStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [iStream close];
		[iStream release];
        iStream = nil;
    }
}

- (void)finish;
{
	_isExecuting = NO;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode 
{
	switch(eventCode) {
        case NSStreamEventHasSpaceAvailable:
        {
            if (stream == oStream)
			{
				uint8_t *readBytes = (uint8_t *)[_requestData bytes];
				readBytes += _writtenBytesCounter; // instance variable to move pointer
				int data_len = [_requestData length];
				unsigned int len = ((data_len - _writtenBytesCounter >= 1024) ?
									1024 : (data_len-_writtenBytesCounter));
				uint8_t buf[len];
				(void)memcpy(buf, readBytes, len);
				len = [oStream write:(const uint8_t *)buf maxLength:len];
				_writtenBytesCounter += len;
				
				if (_writtenBytesCounter == data_len)
					[self requestDidSent];
			}
            break;
        }
		case NSStreamEventHasBytesAvailable:
        {
			if ([_responseData length]>MAX_RESPONSE_SIZE)
			{
				[self setError:@"Response too large to fit into memory"];
				return;
			}
			
			if(!_responseData)
                _responseData = [[NSMutableData data] retain];
            
			uint8_t buf[1024];
            NSInteger len = 0;
			
			len = [(NSInputStream *)stream read:buf maxLength:1024];
			
			if (len>0)
				[_responseData appendBytes:buf length:len];

			break;
		}
			
		case NSStreamEventEndEncountered:
        {
			[self responseDidReceived];
			NSInteger len = [_responseData length];
			NSInteger start = 0;
			uint8_t *buf = (uint8_t *)[_responseData bytes];
			BOOL headerDividerFound = NO;

			//look for \n\n or \r\n\r\n
			if (len)
			{
				BOOL carriageReturnFound = NO;

				for (int i=0;i<len;i++)
				{
					if (buf[i]=='\r') //skip single \r's
						continue;
						
					if (buf[i]=='\n')
					{
						if (carriageReturnFound)
							{
								headerDividerFound = YES;
								start = i+1;
								break;
							}
							else
								carriageReturnFound = YES;
						}
						else
							carriageReturnFound = NO;
				}
				if (!headerDividerFound || len <= start)
				{
					[self setError:NSLocalizedString(@"Invalid rtorrent response (is rtorrent running?)", "Network -> error")];
					break;
				}
			}
			else
            {
				[self setError:NSLocalizedString(@"Invalid rtorrent response (is rtorrent running?)", "Network -> error")];
                break;
            }
			
			NSData *body = [NSData dataWithBytes:(buf+start) length:(len-start)];
			XMLRPCTreeBasedParser* xmlrpcResponse = [[XMLRPCTreeBasedParser alloc] initWithData: body];
//			NSLog(@"%@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
			id result = [xmlrpcResponse parse];
			BOOL fault = [xmlrpcResponse isFault];
			[xmlrpcResponse release];
			
			if (result == nil)//empty response, occured with bad xml. network error?
			{
				[self setError:NSLocalizedString(@"Invalid rtorrent response (is rtorrent running?)", "Network -> error")];
				return;
			}
	
			if (fault)
				[self setError:result];
			else
            {
				[self runResponse:result error:nil];
			}
            break;
        }
		case NSStreamEventErrorOccurred: 
		{
			[self setError:[[stream streamError] localizedDescription]];
			break;
        }
    }
}

- (void) setError:(NSString*) error;
{
	[self finish];
	[self requestDidSent];
	[self responseDidReceived];
	[self runResponse:nil error:error];
}

- (void) runResponse:(NSData*) data error:(NSString*) error
{
    [self finish];
    if (operation == nil && handler)
		handler(data, error);
	else
		[operation processResponse:data error:error];
}
@end
