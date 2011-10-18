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

#import "ToolbarControllerAdditions.h"
#import "ButtonToolbarItem.h"
#import "GroupToolbarItem.h"
#import "ToolbarSegmentedCell.h"
#import "TorrentTableView.h"
#import "Torrent.h"
#import "QuickLookController.h"
#import "DownloadsController.h"
#import "PreferencesController.h"

#define TOOLBAR_REMOVE                      @"Toolbar Remove"
#define TOOLBAR_PAUSE_RESUME_SELECTED       @"Toolbar Pause / Resume Selected"
#define TOOLBAR_PAUSE_STOP_RESUME_SELECTED  @"Toolbar Pause / Stop / Resume Selected"
#define TOOLBAR_PAUSE_SELECTED              @"Toolbar Pause Selected"
#define TOOLBAR_STOP_SELECTED               @"Toolbar Stop Selected"
#define TOOLBAR_RESUME_SELECTED             @"Toolbar Resume Selected"
#define TOOLBAR_QUICKLOOK                   @"Toolbar QuickLook"

typedef enum
{
    TOOLBAR_PAUSE_TAG = 0,
    TOOLBAR_RESUME_TAG = 1,
    TOOLBAR_FORCE_STOP_TAG = 2,
    TOOLBAR_STOP_TAG = 3
} toolbarGroupTag;

@implementation Controller(ToolbarControllerAdditions)
- (void)setupToolbar
{
    NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier: @"NIMainToolbar"];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    [_window setToolbar: toolbar];
    [toolbar release];	
}

- (ButtonToolbarItem *) standardToolbarButtonWithIdentifier: (NSString *) ident
{
    ButtonToolbarItem * item = [[ButtonToolbarItem alloc] initWithItemIdentifier: ident];
    
    NSButton * button = [[NSButton alloc] initWithFrame: NSZeroRect];
    [button setBezelStyle: NSTexturedRoundedBezelStyle];
    [button setStringValue: @""];
    
    [item setView: button];
    [button release];
    
    const NSSize buttonSize = NSMakeSize(36.0, 25.0);
    [item setMinSize: buttonSize];
    [item setMaxSize: buttonSize];
    
    return [item autorelease];
}

#pragma mark Responders
-(IBAction)selectedToolbarClicked:(id)sender
{
    NSInteger tagValue = [sender isKindOfClass: [NSSegmentedControl class]]
	? [(NSSegmentedCell *)[sender cell] tagForSegment: [sender selectedSegment]] : [sender tag];
    switch (tagValue)
    {
        case TOOLBAR_STOP_TAG:
            [self stopSelectedTorrents: sender];
            break;
        case TOOLBAR_PAUSE_TAG:
            [self forcePauseSelectedTorrents: sender];
            break;
        case TOOLBAR_FORCE_STOP_TAG:
            [self forceStopSelectedTorrents: sender];
            break;
        case TOOLBAR_RESUME_TAG:
            [self resumeSelectedTorrents: sender];
            break;
    }
}
#pragma mark NSToolbarDelegate

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects:
            TOOLBAR_REMOVE,
            TOOLBAR_PAUSE_RESUME_SELECTED,
            TOOLBAR_PAUSE_STOP_RESUME_SELECTED,
			TOOLBAR_QUICKLOOK,
            NSToolbarSeparatorItemIdentifier,
            NSToolbarSpaceItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            NSToolbarCustomizeToolbarItemIdentifier, nil];
}


- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects:
            TOOLBAR_REMOVE, NSToolbarSeparatorItemIdentifier,
            TOOLBAR_PAUSE_RESUME_SELECTED, NSToolbarFlexibleSpaceItemIdentifier,
            TOOLBAR_QUICKLOOK, nil];
}

- (NSToolbarItem *) toolbar: (NSToolbar *) toolbar itemForItemIdentifier: (NSString *) ident willBeInsertedIntoToolbar: (BOOL) flag
{
   if ([ident isEqualToString: TOOLBAR_REMOVE])
    {
        ButtonToolbarItem * item = [self standardToolbarButtonWithIdentifier: ident];
        
        [item setLabel: NSLocalizedString(@"Remove", "Remove toolbar item -> label")];
        [item setPaletteLabel: NSLocalizedString(@"Remove Selected", "Remove toolbar item -> palette label")];
        [item setToolTip: NSLocalizedString(@"Remove selected transfers", "Remove toolbar item -> tooltip")];
        [item setImage: [NSImage imageNamed: @"ToolbarRemoveTemplate.png"]];
        [item setTarget: self];
        [item setAction: @selector(removeNoDeleteSelectedTorrents:)];
        
        return item;
    }
    else if ([ident isEqualToString: TOOLBAR_PAUSE_RESUME_SELECTED])
    {
        GroupToolbarItem * groupItem = [[GroupToolbarItem alloc] initWithItemIdentifier: ident];
        
        NSSegmentedControl * segmentedControl = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect];
        [segmentedControl setCell: [[[ToolbarSegmentedCell alloc] init] autorelease]];
        [groupItem setView: segmentedControl];
        NSSegmentedCell * segmentedCell = (NSSegmentedCell *)[segmentedControl cell];
        
        [segmentedControl setSegmentCount: 2];
        [segmentedCell setTrackingMode: NSSegmentSwitchTrackingMomentary];
        
        const NSSize groupSize = NSMakeSize(72.0, 25.0);
        [groupItem setMinSize: groupSize];
        [groupItem setMaxSize: groupSize];
        
        [groupItem setLabel: NSLocalizedString(@"Apply Selected", "Selected toolbar item -> label")];
        if ([_defaults boolForKey:NIForceStopKey])
            [groupItem setPaletteLabel: NSLocalizedString(@"Stop / Pause Selected", "Selected toolbar item -> palette label")];
        else 
            [groupItem setPaletteLabel: NSLocalizedString(@"Resume / Pause Selected", "Selected toolbar item -> palette label")];

        [groupItem setTarget: self];
        [groupItem setAction: @selector(selectedToolbarClicked:)];
        
        [groupItem setIdentifiers: [NSArray arrayWithObjects: TOOLBAR_RESUME_SELECTED, TOOLBAR_PAUSE_SELECTED, nil]];
        
        [segmentedCell setTag: TOOLBAR_RESUME_TAG forSegment: 0];
        [segmentedControl setImage: [NSImage imageNamed: @"ToolbarResumeSelectedTemplate.png"] forSegment: 0];
        [segmentedCell setToolTip: NSLocalizedString(@"Resume selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: 0];
        
        if ([_defaults boolForKey:NIForceStopKey])
        {
            [segmentedCell setTag: TOOLBAR_STOP_TAG forSegment: 1];
            [segmentedControl setImage: [NSImage imageNamed: @"ToolbarStopSelectedTemplate.png"] forSegment: 1];
            [segmentedCell setToolTip: NSLocalizedString(@"Stop selected transfers",
                                                         "Selected toolbar item -> tooltip") forSegment: 1];
        }
        else
        {
            [segmentedCell setTag: TOOLBAR_STOP_TAG forSegment: 1];
            [segmentedControl setImage: [NSImage imageNamed: @"ToolbarPauseSelectedTemplate.png"] forSegment: 1];
            [segmentedCell setToolTip: NSLocalizedString(@"Pause selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: 1];
        }
        
        [groupItem createMenu: [NSArray arrayWithObjects: NSLocalizedString(@"Resume Selected", "Selected toolbar item -> label"), 
                                                          NSLocalizedString(@"Pause Selected", "Selected toolbar item -> label"), 
                                                          nil]];
        
        [segmentedControl release];
        return [groupItem autorelease];
    }
    else if ([ident isEqualToString: TOOLBAR_PAUSE_STOP_RESUME_SELECTED])
    {
        GroupToolbarItem * groupItem = [[GroupToolbarItem alloc] initWithItemIdentifier: ident];
        
        NSSegmentedControl * segmentedControl = [[NSSegmentedControl alloc] initWithFrame: NSZeroRect];
        [segmentedControl setCell: [[[ToolbarSegmentedCell alloc] init] autorelease]];
        [groupItem setView: segmentedControl];
        NSSegmentedCell * segmentedCell = (NSSegmentedCell *)[segmentedControl cell];
        
        [segmentedControl setSegmentCount: 3];
        [segmentedCell setTrackingMode: NSSegmentSwitchTrackingMomentary];
        
        const NSSize groupSize = NSMakeSize(108.0, 25.0);
        [groupItem setMinSize: groupSize];
        [groupItem setMaxSize: groupSize];
        
        [groupItem setLabel: NSLocalizedString(@"Apply Selected", "Selected toolbar item -> label")];
        [groupItem setPaletteLabel: NSLocalizedString(@"Resume / Stop / Pause Selected", "Selected toolbar item -> palette label")];
        [groupItem setTarget: self];
        [groupItem setAction: @selector(selectedToolbarClicked:)];
        
        [groupItem setIdentifiers: [NSArray arrayWithObjects: TOOLBAR_RESUME_SELECTED, TOOLBAR_STOP_SELECTED, TOOLBAR_PAUSE_SELECTED, nil]];
        
        [segmentedCell setTag: TOOLBAR_RESUME_TAG forSegment: 0];
        [segmentedControl setImage: [NSImage imageNamed: @"ToolbarResumeSelectedTemplate.png"] forSegment: 0];
        [segmentedCell setToolTip: NSLocalizedString(@"Resume selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: 0];
        
        [segmentedCell setTag: TOOLBAR_FORCE_STOP_TAG forSegment: 1];
        [segmentedControl setImage: [NSImage imageNamed: @"ToolbarStopSelectedTemplate.png"] forSegment: 1];
        [segmentedCell setToolTip: NSLocalizedString(@"Stop selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: 1];
        
        [segmentedCell setTag: TOOLBAR_PAUSE_TAG forSegment: 2];
        [segmentedControl setImage: [NSImage imageNamed: @"ToolbarPauseSelectedTemplate.png"] forSegment: 2];
        [segmentedCell setToolTip: NSLocalizedString(@"Pause selected transfers",
													 "Selected toolbar item -> tooltip") forSegment: 2];
        
        [groupItem createMenu: [NSArray arrayWithObjects: NSLocalizedString(@"Resume Selected", "Selected toolbar item -> label"),
                                NSLocalizedString(@"Stop Selected", "Selected toolbar item -> label"),
								NSLocalizedString(@"Pause Selected", "Selected toolbar item -> label"), nil]];
        
        [segmentedControl release];
        return [groupItem autorelease];
    }
	else if ([ident isEqualToString: TOOLBAR_QUICKLOOK])
    {
        ButtonToolbarItem * item = [self standardToolbarButtonWithIdentifier: ident];
        [[(NSButton *)[item view] cell] setShowsStateBy: NSContentsCellMask]; //blue when enabled
        
        [item setLabel: NSLocalizedString(@"Quick Look", "QuickLook toolbar item -> label")];
        [item setPaletteLabel: NSLocalizedString(@"Quick Look", "QuickLook toolbar item -> palette label")];
        [item setToolTip: NSLocalizedString(@"Quick Look", "QuickLook toolbar item -> tooltip")];
        [item setImage: [NSImage imageNamed: NSImageNameQuickLookTemplate]];
        [item setTarget: self];
        [item setAction: @selector(toggleQuickLook:)];
        
        return item;
    }
	
    else
        return nil;
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem
{
	NSString * ident = [toolbarItem itemIdentifier];
    
    //enable remove item
    if ([ident isEqualToString: TOOLBAR_REMOVE])
        return [_downloadsView numberOfSelectedRows] > 0;
	
    //enable pause item
    if ([ident isEqualToString: TOOLBAR_PAUSE_SELECTED] || [ident isEqualToString: TOOLBAR_STOP_SELECTED])
    {
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if (torrent.state == NITorrentStateSeeding || torrent.state == NITorrentStateLeeching)
                return YES;
        return NO;
    }
    
    //enable resume item
    if ([ident isEqualToString: TOOLBAR_RESUME_SELECTED])
    {
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if (torrent.state == NITorrentStateStopped || torrent.state == NITorrentStatePaused)
                return YES;
        return NO;
    }

	if ([ident isEqualToString: TOOLBAR_QUICKLOOK])
    {
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if ([[DownloadsController sharedDownloadsController] findLocation:torrent] != nil)
                return YES;
		
        return NO;
    }
	
	
    return YES;
}
@end
