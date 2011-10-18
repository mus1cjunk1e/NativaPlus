//Copyright (C) 2008  Antoine Mercadal
//
//This program is free software; you can redistribute it and/or
//modify it under the terms of the GNU General Public License
//as published by the Free Software Foundation; either version 2
//of the License, or (at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.
//
//You should have received a copy of the GNU General Public License
//along with this program; if not, write to the Free Software
//Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#import <Foundation/Foundation.h>
#import <SecurityFoundation/SFAuthorization.h>

extern	NSString const *AMErrorLoadingSavedState;
extern	NSString const *AMNewGeneralMessage;
extern	NSString const *AMNewErrorMessage;

@class AMServer;

@interface AMSession : NSObject
{
	AMServer 		*currentServer;
	NSUInteger		localPort;
	NSUInteger		remotePort;
	NSUInteger		autoReconnectTimes;
	NSUInteger		maxAutoReconnectRetries;
	BOOL			autoReconnect;
	BOOL			_connected;
	BOOL			_connecting;
	BOOL			tryReconnect;
	NSMutableString *outputContent;
	NSString 		*remoteHost;
	NSString 		*sessionName;
	NSTask			*sshTask;
	NSString		*error;
	NSFileHandle	*outputHandle;
	NSFileHandle	*inputHandle;
	
	SFAuthorization *auth;
	NSTimer			*killTimer;

    void (^openTunnelHandler)(AMSession *sender);

}
@property(readonly)				BOOL				connected;
@property(readwrite)			BOOL				autoReconnect;
@property(readonly)				BOOL				connecting;
@property(readwrite)			NSUInteger			maxAutoReconnectRetries;
@property(readwrite, retain)	AMServer 			*currentServer;
@property(readwrite, retain)	NSString 			*remoteHost;
@property(readwrite, retain)	NSString 			*sessionName;
@property(readwrite, retain)	NSString 			*error;
@property						NSUInteger			localPort;
@property						NSUInteger			remotePort;

@property (copy) void (^openTunnelHandler)(AMSession *sender);

#pragma mark -
#pragma mark Control methods
- (void) closeTunnel;
- (void) openTunnel:(void (^)(AMSession *sender))handler;

#pragma mark -
#pragma mark Observers and delegates
- (void) handleProcessusExecution:(NSNotification *) notification;
- (void) listernerForSSHTunnelDown:(NSNotification *)notification;

#pragma mark -
#pragma mark Helper methods
- (NSString *) prepareSSHCommand;


@end