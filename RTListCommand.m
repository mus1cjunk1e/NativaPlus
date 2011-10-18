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

#import "RTListCommand.h"
#import "Torrent.h"
#import "NSStringRTorrentAdditions.h"

@interface RTListCommand(Private)

- (TorrentState) defineTorrentState:(NSNumber*) state checking:(NSNumber*)checking opened:(NSNumber*) opened complete:(NSNumber *) complete active:(NSNumber *) active;

- (TorrentPriority) defineTorrentPriority:(NSNumber*) priority;

@end

@implementation RTListCommand

@synthesize response;
@synthesize groupCommand = _groupCommand;

- (id)initWithArrayResponse:(ArrayResponseBlock) resp;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    [self setResponse:resp];
    return self;
}

- (void) processResponse:(id) data error:(NSString *) error;
{
	NSMutableArray* result = nil;
	if (error == nil)
	{
		result = [[NSMutableArray alloc] init];
		for (NSArray* row in data)
		{
			Torrent* r = [[Torrent alloc] init];
			r.thash = [row objectAtIndex:0];
			r.name = [row objectAtIndex:1];
			NSNumber*  size = [row  objectAtIndex:2];
			NSNumber*  completed = [row  objectAtIndex:3];
			r.size = [size integerValue];
			r.downloadRate = [completed integerValue];
			NSNumber* state = [row  objectAtIndex:4];
			NSNumber* opened = [row  objectAtIndex:5];
			NSNumber*  speedDownload = [row  objectAtIndex:6];
			r.speedDownload = [speedDownload floatValue];
			NSNumber*  speedUpload = [row  objectAtIndex:7];
			r.speedUpload = [speedUpload floatValue];
			NSNumber*  uploadRate = [row  objectAtIndex:8];
			r.uploadRate = [uploadRate integerValue];
			r.dataLocation = [row objectAtIndex:9];
			NSNumber *conn = [row  objectAtIndex:10];
			NSNumber *notConn = [row  objectAtIndex:11];
			NSNumber *compl = [row  objectAtIndex:12];
			r.totalPeersLeech = [conn integerValue] - [compl integerValue];
			r.totalPeersSeed = [compl integerValue];
			r.totalPeersDisconnected = [notConn integerValue];
			r.priority = [self defineTorrentPriority:[row objectAtIndex:13]];
			r.isFolder = [[row  objectAtIndex:14] boolValue];
			NSString* errorMessage = [row  objectAtIndex:15];
			r.error = [errorMessage isEqualToString:@""]?nil:errorMessage;
			NSString *groupName = [row  objectAtIndex:16];
			
			NSString *decodedGroupName = [groupName isEqualToString:@""]?nil:[groupName urlDecode];
			r.groupName = decodedGroupName;
			
			NSNumber*  checking = [row  objectAtIndex:17];
            
            NSNumber*  complete = [row  objectAtIndex:18];
            
            NSNumber*  active = [row  objectAtIndex:19];
			
			r.state = [self defineTorrentState:state checking:checking opened:opened complete:complete active:active];
			
			[result addObject:r];
			[r release];
		}
		[result autorelease];
	}
	if (response)
		response(result, error);
}

- (NSString *) command;
{
	return @"d.multicall";
}
- (NSArray *) arguments;
{
	return [NSArray arrayWithObjects:
			@"main", 
			@"d.get_hash=", 
			@"d.get_name=", 
			@"d.get_size_bytes=",
			@"d.get_completed_bytes=",
			@"d.get_state=",
			@"d.is_open=",
			@"d.get_down_rate=",
			@"d.get_up_rate=",
			@"d.get_up_total=",
			@"d.get_base_path=",
			@"d.get_peers_connected=",
			@"d.get_peers_not_connected=",
			@"d.get_peers_complete=",
			@"d.get_priority=",
			@"d.is_multi_file=",
			@"d.get_message=",
			[_groupCommand stringByAppendingString:@"="],
			@"d.is_hash_checking=",
            @"d.get_complete=",
            @"d.is_active=",
			nil];
}

- (void)dealloc
{
	[self setResponse:nil];
	[self setGroupCommand:nil];
	[super dealloc];
}
@end

@implementation RTListCommand(Private)

- (TorrentState) defineTorrentState:(NSNumber*) state checking:(NSNumber*)checking opened:(NSNumber*) opened complete:(NSNumber *) complete active:(NSNumber *) active
{
	if ([checking boolValue]) 
		return NITorrentStateChecking;

    if (![active boolValue])
        return [opened boolValue]?NITorrentStatePaused:NITorrentStateStopped;
    
	switch ([state intValue]) {
		case 1: //started
			if ([opened intValue]==0)
				return NITorrentStateStopped;
			else
			{
				if ([complete boolValue])
					return NITorrentStateSeeding;
				else
					return NITorrentStateLeeching;
			}
		case 0: //stopped
			return NITorrentStateStopped;
	}
	return NITorrentStateUnknown;
}

- (TorrentPriority) defineTorrentPriority:(NSNumber*) priority
{
	switch ([priority integerValue]) {
		case 0:
			return NITorrentPriorityOff;
		case 1:
			return NITorrentPriorityLow;
		case 2:
			return NITorrentPriorityNormal;
		case 3:
			return NITorrentPriorityHigh;
	}
	return NITorrentPriorityNormal;
}
@end