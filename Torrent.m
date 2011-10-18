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

#import "Torrent.h"
#import "NativaConstants.h"
#import "BEncoding.h"
#import "FileListNode.h"

@implementation Torrent

@synthesize name, 
            size, 
            thash, 
            state, 
            speedDownload,
            speedUpload,
            dataLocation,
            uploadRate,
            downloadRate,
            totalPeersSeed,
            totalPeersLeech,
            totalPeersDisconnected,
            priority,
            isFolder,
            error,
            groupName,
            file,
            trackers,
            flatFileList,
            comment;

+ (id)torrentWithData:(NSData *) encodedData
{
    Torrent *result = [[Torrent alloc] init];
    
    id decodedData = [BEncoding objectFromEncodedData:encodedData withTypeAdvisor:(GEBEncodedTypeAdvisor)^(NSArray *keyStack) {
		if ([[keyStack lastObject] isEqualToString:@"pieces"])
			return GEBEncodedDataType;
        else if ([[keyStack lastObject] isEqualToString:@"info"])
                return GEBEncodedDataType;
		else {
			return GEBEncodedStringType;
		}
	}];

    NSData *info = [decodedData valueForKey:@"info"];
    
    result.name = [info valueForKey:@"name"];
    
    result.size = [[info valueForKey:@"length"] integerValue];
    
    NSArray* fileNames = [info valueForKey:@"files"];
    
    FileListNode *root;
    
    NSMutableArray* flatFiles = [NSMutableArray arrayWithCapacity:[fileNames count]];
    
    uint64_t torrentSize = 0;
    
    if (fileNames != nil)
    {
        NSMutableDictionary *folders = [NSMutableDictionary dictionary];
        root = [[FileListNode alloc] initWithFolderName:result.name path:result.name];
        int fileIndex = 0;
        for (NSDictionary *f in fileNames)
        {
            FileListNode *parent = root;
            NSArray *fileList = [f valueForKey:@"path"];
            NSString *fileName = [fileList lastObject];
            uint64_t fileSize = [[f valueForKey:@"length"] unsignedLongLongValue];
            torrentSize += fileSize;
            for (NSString *pe in fileList)
            {
                NSString *path = [NSString stringWithFormat:@"%@/%@", [parent path], pe];
                if (pe == fileName)
                {
                    FileListNode *file = [[FileListNode alloc] initWithFileName:fileName 
                                                                           path: path
                                                                           size: fileSize
                                                                          index: fileIndex];
                    [parent insertChild:file];
                    [flatFiles addObject:file];
                    [file release];
                }
                else
                {
                    FileListNode *folder = [folders objectForKey:path];
                    if (folder == nil)
                    {
                        folder = [[FileListNode alloc] initWithFolderName:pe path:path];
                        [parent insertChild:folder];
                        parent = folder;
                        [folders setObject:folder forKey:path];
                        [folder release];
                    }
                }
            }
            fileIndex++;
        }
    }
    else
    {
        root = [[FileListNode alloc] initWithFileName:result.name 
                                                 path: result.name
                                                 size: result.size
                                                index: 0];
        [flatFiles addObject:root];
    }
    result.size += torrentSize;
    result.file = root;
    result.flatFileList = flatFiles;
    [root release];
    NSString *trackerUrl = [decodedData valueForKey:@"announce"];
    NSMutableArray *trackersList = trackerUrl == nil?nil:[NSMutableArray arrayWithObjects:
                                                          trackerUrl,
                                                          nil];

    NSArray *trackerUrls = [decodedData valueForKey:@"announce-list"];
    if (trackerUrls != nil)
    {
        if (trackersList == nil)
            trackersList = [NSMutableArray arrayWithArray:trackerUrls];
        else
            [trackersList addObjectsFromArray:trackerUrls];
    }

    result.trackers = trackersList;
    
    result.comment = [decodedData valueForKey:@"comment"];

    return [result autorelease];
}

- (void)dealloc
{
	[self setName:nil];
	[self setThash:nil];
	[_icon release];
	[self setDataLocation:nil];
	[self setError:nil];
	[self setGroupName:nil];
    [self setTrackers:nil];
    [self setFile:nil];
    [self setFlatFileList:nil];
    [self setComment:nil];
	[super dealloc];
}

- (NSUInteger)hash;
{
	return [thash hash];
}

- (BOOL)isEqual:(id)anObject
{
	if ([anObject isKindOfClass: [Torrent class]])
		return [[anObject thash] isEqualToString: thash];
	else
		return NO;
}

- (void) update: (Torrent *) anotherItem;
{
	self.state = anotherItem.state;
	self.speedUpload = anotherItem.speedUpload;
	self.speedDownload = anotherItem.speedDownload;
	self.uploadRate = anotherItem.uploadRate;
	self.downloadRate = anotherItem.downloadRate;
	self.totalPeersSeed=anotherItem.totalPeersSeed;
	self.totalPeersLeech=anotherItem.totalPeersLeech;
	self.totalPeersDisconnected=anotherItem.totalPeersDisconnected;
	self.dataLocation = (anotherItem.dataLocation == nil?self.dataLocation:anotherItem.dataLocation);
	self.priority = anotherItem.priority;
	self.error = anotherItem.error;
	self.groupName = anotherItem.groupName;
}

- (double) progress
{
	return ((float)downloadRate/(float)size);
}

- (NSImage*) icon
{
	if (!_icon)
		_icon = [[[NSWorkspace sharedWorkspace] iconForFileType: [self isFolder] ? NSFileTypeForHFSTypeCode('fldr')
															   : [[self name] pathExtension]] retain];

	return _icon;
}

- (CGFloat) ratio
{
	if (downloadRate == 0)
		return NI_RATIO_NA;
	else
		return (CGFloat)uploadRate/(CGFloat)downloadRate;
}
@end
