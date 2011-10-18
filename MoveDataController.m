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

#import "MoveDataController.h"
#import "SynthesizeSingleton.h"
#import "Torrent.h"
#import "DownloadsController.h"
#import "GroupsController.h"

@implementation MoveDataController
SYNTHESIZE_SINGLETON_FOR_CLASS(MoveDataController);
@synthesize torrents=_torrents;
@synthesize max, current, isWorking;

- (id) init
{
    if (self = [super init]) 
	{
		mruList = [[[NSMutableArray alloc] init] retain];
    }
    return self;
}

- (void) openMoveDataWindow: (NSWindow*) window torrents:(NSArray*) torrents;
{
    [self setTorrents:[NSArray arrayWithArray:torrents]];

    [self setMax:[_torrents count]];
    [self setCurrent:0];
    [self setIsWorking:NO];
    
    [mruList removeAllObjects];
    for (NSInteger i=0;i<[[GroupsController groups] numberOfGroups];i++)
    {
        NSInteger index = [[GroupsController groups] indexForRow:i];
        NSString *path = [[GroupsController groups] customDownloadLocationForIndex:index];
        if (path != nil && ![path isEqualToString:@""])
            [mruList addObject:path];
    }
    
	if ([self window] == nil)
            //Check the _progressSheet instance variable to make sure the custom sheet does not already exist.
        [NSBundle loadNibNamed: @"MoveData" owner: self];
    
    if ([torrents count] == 1)
    {
        Torrent *torrent = [torrents objectAtIndex:0];
        [_locationField setStringValue:torrent.dataLocation];
    }
    
    [NSApp beginSheet: [self window]
	   modalForWindow: window
		modalDelegate: self
	   didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];
}
- (void) dealloc
{
    [self setTorrents:nil];
    [mruList dealloc];
    [super dealloc];
}

- (IBAction)close: (id)sender
{
    [NSApp endSheet:[self window]];
}

- (IBAction)move: (id)sender
{
    [self setIsWorking:YES];
    
    __block MoveDataController *blockSelf = self;
    
    for (Torrent *torrent in _torrents)
    {
        [[DownloadsController sharedDownloadsController] moveData:torrent
                                                        location:[_locationField stringValue]
                                                          handler:^(NSString *error)
                                                          {
                                                              [blockSelf setCurrent:[blockSelf current]+1];
                                                              if ([blockSelf current] == [blockSelf max])
                                                              {
                                                                  [blockSelf setIsWorking:NO];
                                                                  [NSApp endSheet:[blockSelf window]];
                                                              }
                                                          }];
    }
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
    [sheet orderOut:self];
}

#pragma mark -
#pragma mark NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return [mruList count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [mruList objectAtIndex:index];
}
@end
