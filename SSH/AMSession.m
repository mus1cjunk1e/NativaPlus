// Copyright (C) 2008  Antoine Mercadal
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#import "AMSession.h"
#import "AMServer.h"
#include <signal.h>

@interface AMSession(Private)
-(void) analyzeOutput:(NSData*) data;
-(void)killTimeoutedTask;
-(void)terminateTask;
-(void)_openTunnel:(void (^)(AMSession *sender))handler;
@end

@implementation AMSession

@synthesize	sessionName;
@synthesize remoteHost;
@synthesize connected = _connected;
@synthesize connecting = _connecting;
@synthesize currentServer;
@synthesize autoReconnect;
@synthesize maxAutoReconnectRetries;
@synthesize remotePort;
@synthesize localPort;
@dynamic	error;
@synthesize openTunnelHandler;

#pragma mark Initilizations

- (id) init
{
	if ((self = [super init]) == nil)
		return nil;
	
	_connected = NO;
	_connecting = NO;
	autoReconnectTimes = 0;

	outputContent	= [[NSMutableString alloc] init];

	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[sessionName release];
	[remoteHost release];
	
	[self terminateTask];
	
	[sshTask  release];
	[outputContent release];
	[error release];
	[currentServer release];
    [self setOpenTunnelHandler:nil];
	[super dealloc];
}

- (NSString *) prepareSSHCommand  
{
    NSMutableString *argumentsString = [NSMutableString stringWithString: @"ssh "];
	
	if ([currentServer useSSHV2])
		[argumentsString appendString:@" -2 "];
    
    if ([currentServer compressionLevel]>0)
       [argumentsString appendFormat:@" -C -o CompressionLevel=%d ", [currentServer compressionLevel]];
	
	[argumentsString appendString:@"-N -L "];
	[argumentsString appendFormat:@"%d", localPort];
	[argumentsString appendString:@":"];
	[argumentsString appendString:remoteHost];
	[argumentsString appendString:@":"];
	[argumentsString appendFormat:@"%d", remotePort];
	
	[argumentsString appendString:@" "];
	[argumentsString appendString:[currentServer username]];
	[argumentsString appendString:@"@"];
	[argumentsString appendString:[currentServer host]];
	[argumentsString appendString:@" -p "];
    [argumentsString appendFormat:@"%d", [currentServer port]];

	NSLog(@"Used SSH Command : %@", argumentsString);
	
	return argumentsString;
}




#pragma mark Control methods

- (void) openTunnel:(void (^)(AMSession *sender))handler;
{
    if ([currentServer host] == nil || [[currentServer host] isEqualToString:@""]) 
    {
        [self setError:@"SSH host cannot be empty"];
        [self willChangeValueForKey:@"connected"];
        [self willChangeValueForKey:@"connecting"];
        _connecting = NO;
        _connected = NO;
        [self didChangeValueForKey:@"connecting"];
        [self didChangeValueForKey:@"connected"];
        
        if (handler)
            handler(self);
        return;
    }
    
    if ([currentServer username] == nil || [[currentServer username] isEqualToString:@""]) 
    {
        [self setError:@"SSH user name cannot be empty"];
        [self willChangeValueForKey:@"connecting"];
        _connecting = NO;
        _connected = NO;
        [self didChangeValueForKey:@"connecting"];
        [self didChangeValueForKey:@"connected"];
        
        if (handler)
            handler(self);
        return;
    }
    
    
    [self willChangeValueForKey:@"connected"];
    [self willChangeValueForKey:@"connecting"];
    _connecting = YES;
    _connected = NO;
    [self didChangeValueForKey:@"connecting"];
    [self didChangeValueForKey:@"connected"];

    [self _openTunnel:handler];	
}

- (void) closeTunnel
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:sshTask];

	tryReconnect = NO;

	NSLog(@"Session %@ is now closed.", [self sessionName]);
    [self willChangeValueForKey:@"connecting"];
    [self willChangeValueForKey:@"connected"];
    _connecting = NO;
    _connected = NO;
    [self didChangeValueForKey:@"connecting"];
    [self didChangeValueForKey:@"connected"];
	[self terminateTask];
	autoReconnectTimes = 0;
}



#pragma mark Observers and delegates
- (void) handleProcessusExecution:(NSNotification *) aNotification
{
	NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	[self analyzeOutput:data];
}

- (void) listernerForSSHTunnelDown:(NSNotification *)notification
{	
	NSDate *future = [NSDate dateWithTimeIntervalSinceNow: 0.1];
    [[NSRunLoop currentRunLoop] runUntilDate: future];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:sshTask];
	[[NSNotificationCenter defaultCenter]  removeObserver:self name:NSFileHandleReadCompletionNotification  object:outputHandle];

    if (_connected)
    {
		[self willChangeValueForKey:@"connected"];
		_connected = NO;
		[self didChangeValueForKey:@"connecting"];
    }
    
	if (tryReconnect && autoReconnectTimes<maxAutoReconnectRetries)
	{
		NSLog(@"reconnecting ssh tunnel ...");
		autoReconnectTimes++;
        if (!_connecting)
        {
            [self willChangeValueForKey:@"connecting"];
            _connecting = YES;
            [self didChangeValueForKey:@"connecting"];
        }
		[self _openTunnel:openTunnelHandler];
	}
	else 
	{
		NSLog(@"unable to connect");
		autoReconnectTimes = 0;
		if (error == nil)
			[self setError:@"SSH: unknown error"];
		[self willChangeValueForKey:@"connecting"];
		[self willChangeValueForKey:@"connected"];
		_connecting = NO;
		_connected = NO;
		[self didChangeValueForKey:@"connecting"];
		[self didChangeValueForKey:@"connected"];
        if (openTunnelHandler != nil)
            openTunnelHandler(self);
	}

}
-(NSString*) error
{
	return error;
}

-(void)setError:(NSString *)newValue {
    if (error != newValue) {
        [error release];
        error = [newValue retain];
    }
	if (error)
		NSLog(@"ssh tunnel error: %@", error);
}
@end

@implementation AMSession(Private)
-(void) analyzeOutput:(NSData*) data
{
	if ([data length])
	{
		NSPredicate *checkError			= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'CONNECTION_ERROR'"];
		NSPredicate *checkWrongPass		= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'WRONG_PASSWORD'"];
		NSPredicate *checkConnected		= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'CONNECTED'"];
		NSPredicate *checkRefused		= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'CONNECTION_REFUSED'"];
		NSPredicate *checkTimeout		= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'CONNECTION_TIMEOUT'"];
		NSPredicate *checkWrongHostname	= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'WRONG_HOSTNAME'"];
		NSPredicate *checkPort			= [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'Address already in use'"];
		
		NSString* stmp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		
		[outputContent appendString:stmp];
		
		NSLog(@"ssh said: %@", stmp);
		
		[stmp release];
		
		if ([checkError evaluateWithObject:outputContent] == YES)
		{
			[self setError: @"SSH connection error. Look into console for details"];
			[self terminateTask];
			
		}
		else if ([checkWrongPass evaluateWithObject:outputContent] == YES)
		{
			[self setError: @"Wrong SSH user/password"];
			[self terminateTask];
		}
		else if ([checkRefused evaluateWithObject:outputContent] == YES)
		{
			[self setError: @"SSH connection refused"];
			[self terminateTask];
		}		
		else if ([checkWrongHostname evaluateWithObject:outputContent] == YES)
		{
			[self setError: [NSString stringWithFormat:@"Wrong SSH host name: %@", [currentServer host]]];
			[self terminateTask];
		}		
		else if ([checkTimeout evaluateWithObject:outputContent] == YES)
		{
			[self setError: @"SSH connection timeout. Private key authentication?"];
			[self terminateTask];
		}		
		else if ([checkPort evaluateWithObject:outputContent] == YES)
		{
			[self setError: [NSString stringWithFormat:@"SSH unable to bind to local port %d", localPort]];
			[self terminateTask];
		}
		else if ([checkConnected evaluateWithObject:outputContent] == YES)
		{
			[[NSNotificationCenter defaultCenter]  removeObserver:self name:NSFileHandleReadCompletionNotification  object:outputHandle];
			[outputHandle closeFile];
			[self willChangeValueForKey:@"connecting"];
			[self willChangeValueForKey:@"connected"];
			_connecting = NO;
			_connected = YES;
			[self didChangeValueForKey:@"connecting"];
			[self didChangeValueForKey:@"connected"];
			//reset autoreconnect counter
			autoReconnectTimes = 0;
            if (openTunnelHandler != nil)
                openTunnelHandler(self);

		}
		else
			[outputHandle readInBackgroundAndNotify];
	}
}
-(void)killTimeoutedTask
{
	if (_connected || ![sshTask isRunning])
		return;
	
	[self setError: @"SSH process not responded."];
	[self terminateTask];
}
-(void)terminateTask
{
	if ([sshTask isRunning])
	{
		[sshTask terminate];

        //wait a bit for termination
        for (int i=0;i<10;i++)
        {
            if (![sshTask isRunning])
                break;
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        
        // aggressively terminate if still running
		if ([sshTask isRunning]) 
		{
			int pid = [sshTask processIdentifier];
            NSLog(@"SSH: cannot terminate task gracefully, kill -9 %d", pid);
			kill(pid, 9);
		}
		[sshTask release];
		sshTask = nil;
	}
	
}
-(void)_openTunnel:(void (^)(AMSession *sender))handler
{
    
    NSString			*helperPath;
	NSArray				*args;
	NSString            *argumentsString;
	
    [self setOpenTunnelHandler:handler];
    
	tryReconnect = autoReconnect;
    
	[self setError: nil];
	
	NSPipe *stdOut			= [NSPipe pipe];
	NSPipe *stdIn			= [NSPipe pipe];
	
	
	[sshTask release];
    
	sshTask			= [[NSTask alloc] init];
	
	helperPath		= [[NSBundle mainBundle] pathForResource:@"SSHCommand" ofType:@"sh"];
	
	argumentsString = [self prepareSSHCommand];
	
	args			= [NSArray arrayWithObjects:argumentsString, nil];
    
	[outputContent setString:@""];
    
	[sshTask setLaunchPath:helperPath];
    
	[sshTask setArguments:args];
    
	[sshTask setStandardOutput:stdOut];
	[sshTask setStandardInput:stdIn];
	
	outputHandle = [[sshTask standardOutput] fileHandleForReading];
    
	inputHandle = [[sshTask standardInput] fileHandleForWriting];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleProcessusExecution:)
												 name:NSFileHandleReadCompletionNotification
											   object:outputHandle];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(listernerForSSHTunnelDown:) 
												 name:NSTaskDidTerminateNotification
											   object:sshTask];
	
	[outputHandle readInBackgroundAndNotify];
	
	[auth permitWithRight:"system.privileges.admin" flags:kAuthorizationFlagDefaults|kAuthorizationFlagInteractionAllowed|
	 kAuthorizationFlagExtendRights|kAuthorizationFlagPreAuthorize];
	
	[sshTask launch];
    
    
	[inputHandle writeData:[[(currentServer.password==nil || currentServer.useSSHKeyLogin?@"":[currentServer password]) stringByAppendingString:@"\n"] dataUsingEncoding: NSASCIIStringEncoding]];
    
	NSLog(@"Session %@ is now launched.", [self sessionName]);
	[killTimer invalidate];
    [killTimer release];
	killTimer = [NSTimer scheduledTimerWithTimeInterval:90
                                                 target:self 
                                               selector:@selector(killTimeoutedTask) 
                                               userInfo:nil 
                                                repeats:NO];
	[killTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:killTimer forMode:NSDefaultRunLoopMode];
}
@end
