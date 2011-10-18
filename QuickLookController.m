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

#import "QuickLookController.h"
#include "TorrentTableView.h"
#include "Torrent.h"
#include "DownloadsController.h"
#include "TorrentTableView.h"
#include <QuickLook/QuickLook.h>
#include "SynthesizeSingleton.h"

@interface TorrentTableView (QLPreviewPanelController)
@end

@implementation TorrentTableView (QLPreviewPanelController)
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel
{
	return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
	[[QuickLookController sharedQuickLookController] beginPanel:panel window:[self window] view:self];
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
	[[QuickLookController sharedQuickLookController] endPanel];
}
@end

@interface Torrent (QLPreviewItem) <QLPreviewItem>

@end

@implementation Torrent (QLPreviewItem)
- (NSURL *)previewItemURL
{
    NSString *location = [[DownloadsController sharedDownloadsController] findLocation:self];
	return (location==nil?nil:[NSURL fileURLWithPath: location]);
}

- (NSString *)previewItemTitle
{
    return self.name;
}

@end



@implementation QuickLookController
SYNTHESIZE_SINGLETON_FOR_CLASS(QuickLookController);

+(void) show
{
	if ([[QLPreviewPanel sharedPreviewPanel] isVisible])
		[[QLPreviewPanel sharedPreviewPanel] orderOut: nil];
	else
		[[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront: nil];
}

@synthesize isVisible = _isVisible;

-(void) beginPanel:(QLPreviewPanel*) panel window:(NSWindow*)window view:(TorrentTableView*) view
{
	_window = window;
	_view = view;

	if (_torrents == nil)
	{
		_torrents = [[NSMutableArray alloc] init];
		[_torrents retain];
	}
	
	[_torrents removeAllObjects];

	for (Torrent * torrent in [_view selectedTorrents])
	{
		if ([[DownloadsController sharedDownloadsController] findLocation:torrent] != nil)
			[_torrents addObject:torrent];
	}
	
	self.isVisible = YES;
	_panel = [panel retain];
	_panel.delegate = self;
	_panel.dataSource = self;
}

-(void) endPanel;
{
	self.isVisible = NO;
	
	[_panel release];
	_panel = nil;
	
}


// Quick Look panel support


- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel;
{
	return YES;
}

// Quick Look panel data source

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
	return [_torrents count];
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
{
    return [_torrents objectAtIndex:index];
}

// Quick Look panel delegate

- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
{
   // redirect all key down events to the table view
    if ([event type] == NSKeyDown) 
	{
        [_view keyDown:event];
        return NO;
    }
    return YES;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item
{
	if (![_window isVisible])
		return NSZeroRect;
	
	const NSInteger row = [_view rowForItem: item];
	if (row == -1)
		return NSZeroRect;
	
	NSRect frame = [_view iconRectForRow: row];
	
	if (!NSIntersectsRect([_view visibleRect], frame))
		return NSZeroRect;
	
	frame.origin = [_view convertPoint: frame.origin toView: nil];
	frame.origin = [_window convertBaseToScreen: frame.origin];
	frame.origin.y -= frame.size.height;
	return frame;
}

// This delegate method provides a transition image between the table view and the preview panel
- (id)previewPanel:(QLPreviewPanel *)panel transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(NSRect *)contentRect
{
    Torrent* torrent = (Torrent *)item;

    return [torrent icon];
}
@end
