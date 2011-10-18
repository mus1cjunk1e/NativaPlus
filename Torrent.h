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

#import <Foundation/Foundation.h>

typedef enum 
{ 
	NITorrentStateUnknown = 0,
	NITorrentStateSeeding = 1,
	NITorrentStateLeeching = 2,
	NITorrentStateChecking = 3,
	NITorrentStateStopped = 4,
    NITorrentStatePaused = 5
} TorrentState;

typedef enum 
{ 
	NITorrentPriorityOff = 0,
	NITorrentPriorityLow = 1,
	NITorrentPriorityNormal = 2,
	NITorrentPriorityHigh = 3,
} TorrentPriority;

@class FileListNode;

@interface Torrent : NSObject 
{
	NSString        *name;
	
	NSString        *thash;
	
	uint64_t        size;

	TorrentState    state;
	
	NSImage*        _icon;
	
	CGFloat         speedDownload;
	
	CGFloat         speedUpload;
	
	uint64_t        downloadRate;
	
	uint64_t        uploadRate;
	
	NSInteger       totalPeersSeed;
	
	NSInteger       totalPeersLeech;
	
	NSInteger       totalPeersDisconnected;
	
	NSString        *dataLocation;
	
	TorrentPriority priority;
	
	NSString        *error;
	
	BOOL            isFolder;
	
	NSString        *groupName;
    
    NSArray         *trackers;
    
    FileListNode    *file;
    
    NSArray         *flatFileList;
    
	NSString        *comment;
}
@property (readwrite, retain) NSString  *name;

@property (readwrite, retain) NSString  *thash;

@property uint64_t                      size;

@property TorrentState                  state;

@property CGFloat                       speedDownload;

@property CGFloat                       speedUpload;

@property (retain) NSString             *dataLocation;

@property uint64_t                      downloadRate;

@property uint64_t                      uploadRate;

@property NSInteger                     totalPeersSeed;

@property NSInteger                     totalPeersLeech;

@property NSInteger                     totalPeersDisconnected;

@property TorrentPriority               priority;

@property BOOL                          isFolder;

@property (retain) NSString             *error;

@property (retain) NSString             *groupName;

@property (retain) FileListNode         *file;

@property (retain) NSArray              *trackers;

@property (retain) NSArray              *flatFileList;

@property (retain) NSString             *comment;

- (void) update: (Torrent *) anotherItem;
- (double) progress;
- (NSImage*) icon;
- (CGFloat) ratio;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)anObject;
+ (id)torrentWithData:(NSData *) data;
@end