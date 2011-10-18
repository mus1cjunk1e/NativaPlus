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

#import "Controller.h"
#import "DownloadsController.h"
#import "PreferencesController.h"
#import "TorrentViewController.h"
#import "Torrent.h"
#import "TorrentTableView.h"
#import "ProcessesController.h"
#import <Growl/Growl.h>
#import "DragOverlayWindow.h"
#import "ToolbarControllerAdditions.h"
#import "QuickLookController.h"
#import "GroupsController.h"
#import "TorrentViewController.h"
#import "MoveDataController.h"

#define ACTION_MENU_PRIORITY_HIGH_TAG 101
#define ACTION_MENU_PRIORITY_NORMAL_TAG 102
#define ACTION_MENU_PRIORITY_LOW_TAG 103

#define WINDOW_REGULAR_WIDTH    500.0
#define	MENU_BAR_HEIGHT 21

static NSString* DownloadsViewChangedContext            = @"DownloadsViewChangedContext";
static NSString* ConnectedContext                       = @"ConnectedContext";
static NSString* GlobalSpeedLimitChangedContext         = @"GlobalSpeedLimitChangedContext";

@interface Controller(Private)
- (NSRect) sizedWindowFrame;
- (NSRect) windowFrameByAddingHeight: (CGFloat) height checkLimits: (BOOL) check;
- (void) updateForExpandCollape;
- (void) connected;
@end

@implementation Controller

+(void) initialize
{
	//Create dictionary
	NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];
	
	//Put defaults into dictionary
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:NITrashDownloadDescriptorsKey];

	[defaultValues setObject:[NSNumber numberWithInteger:3]
					  forKey:NIRefreshRateKey];

	[defaultValues setObject:[NSNumber numberWithInteger:300]
					  forKey:NIUpdateGlobalsRateKey];

	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:NIAutoSizeKey];

    [defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:NIForceStopKey];

    [defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:NIGlobalSpeedLimitMaxAuto];

    [defaultValues setObject:[NSNumber numberWithDouble:20]
					  forKey:NIGlobalSpeedLimitMaxDownload];

    [defaultValues setObject:[NSNumber numberWithDouble:20]
					  forKey:NIGlobalSpeedLimitMaxUpload];

    [defaultValues setObject:[NSNumber numberWithDouble:10]
					  forKey:NIGlobalSpeedLimitMinDownload];
    
    [defaultValues setObject:[NSNumber numberWithDouble:10]
					  forKey:NIGlobalSpeedLimitMinUpload];
    
	//Register the dictionary of defaults
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];

	//Growl needs it
	[GrowlApplicationBridge setGrowlDelegate:@""];
}

- (id)init
{
    if (self = [super init]) 
	{
		_defaults = [NSUserDefaults standardUserDefaults];
    }
    return self;
}

- (void)awakeFromNib
{
	[self setupToolbar];

	//for QuickLook functionality
	[_window makeFirstResponder:_downloadsView];
	
	_overlayWindow = [[DragOverlayWindow alloc] initWithWindow: _window];
	
	//window min height
    NSSize contentMinSize = [_window contentMinSize];
    contentMinSize.height = [[_window contentView] frame].size.height - [[_downloadsView enclosingScrollView] frame].size.height
	+ [_downloadsView rowHeight] + [_downloadsView intercellSpacing].height;
    [_window setContentMinSize: contentMinSize];
    //[_window setContentBorderThickness: NSMinY([[_downloadsView enclosingScrollView] frame]) forEdge: NSMinYEdge];
	
	//bottom bar for window
	//http://iloveco.de/bottom-bars-in-cocoa/
	[_window setContentBorderThickness:24.0 forEdge:NSMinYEdge];

    //observe notifications
    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	
	[nc addObserver: self selector: @selector(updateForExpandCollape)
			   name: @"OutlineExpandCollapse" object: nil];

    [nc addObserver: self selector: @selector(setWindowSizeToFit)
			   name: @"AutoSizeSettingChange" object: nil];
	
	[_viewController addObserver:self
			 forKeyPath:@"numberOfRowsInView"
				options:0
				context:&DownloadsViewChangedContext];

    [[DownloadsController sharedDownloadsController] addObserver:self
                      forKeyPath:@"globalDownloadSpeedLimit"
                         options:0
                         context:&GlobalSpeedLimitChangedContext];

    [[DownloadsController sharedDownloadsController] addObserver:self
                     forKeyPath:@"globalUploadSpeedLimit"
                        options:0
                        context:&GlobalSpeedLimitChangedContext];
    
    [[DownloadsController sharedDownloadsController] addObserver:self
                                                      forKeyPath:@"connected"
                                                         options:0
                                                         context:&ConnectedContext];
    [[DownloadsController sharedDownloadsController] addObserver:self
                                                      forKeyPath:@"connecting"
                                                         options:0
                                                         context:&ConnectedContext];
}

-(IBAction)showPreferencePanel:(id)sender;
{
    [[PreferencesController sharedPreferencesController] openPreferences:NIPReferencesViewDefault];
}

-(IBAction)removeNoDeleteSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] erase:t withData:NO response:nil];
	[_downloadsView deselectAll: nil];
}

-(IBAction)removeDeleteSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] erase:t withData:YES response:nil];
	[_downloadsView deselectAll: nil];
}

-(IBAction)stopSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] stop:t force:[_defaults boolForKey:NIForceStopKey] handler:nil];
}

-(IBAction)forceStopSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] stop:t force:YES handler:nil];
}

-(IBAction)forcePauseSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] stop:t force:NO handler:nil];
}

-(IBAction)resumeSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *t in torrents)
		[[DownloadsController sharedDownloadsController] start:t handler:nil];
}

-(IBAction)checkSelectedTorrents:(id)sender
{
	for (Torrent *torrent in [_downloadsView selectedTorrents])
		[[DownloadsController sharedDownloadsController] check:torrent response:nil];
	
}
//opens window for selecting torrent
- (void) openShowSheet: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
	
    [panel setAllowsMultipleSelection: YES];
    [panel setCanChooseFiles: YES];
    [panel setCanChooseDirectories: NO];
	
    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects: @"org.bittorrent.torrent", @"torrent", nil]
				   modalForWindow: _window modalDelegate: self didEndSelector: @selector(openSheetClosed:returnCode:contextInfo:)
					  contextInfo: nil];
}

- (void) openSheetClosed: (NSOpenPanel *) panel returnCode: (NSInteger) code contextInfo: (NSNumber *) useOptions
{
    if (code == NSOKButton)
		[[DownloadsController sharedDownloadsController] add:[panel filenames]];
}

- (IBAction) toggleQuickLook:(id)sender
{
	[QuickLookController show];
}

- (IBAction) revealSelectedTorrents:(id)sender
{
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *torrent in torrents)
		[[DownloadsController sharedDownloadsController] reveal:torrent];
	
}

- (void) setGroup: (id) sender
{
	NSString *group = [[GroupsController groups] nameForIndex:[sender tag]];

	if (_menuTorrent == nil)
	{
		for (Torrent * torrent in [_downloadsView selectedTorrents])
		{
			[[DownloadsController sharedDownloadsController] setGroup:torrent group:group response:nil];
			[_downloadsView deselectAll: nil];
		}
	}
	else
	{
		[[DownloadsController sharedDownloadsController] setGroup:_menuTorrent group:group response:nil];
	}
}

- (void) showGroupMenuForTorrent:(Torrent *) torrent atLocation:(NSPoint) location
{
	_menuTorrent = [torrent retain];
	
	[_groupMenu popUpMenuPositioningItem: nil atLocation: location inView: _downloadsView];
	
	[_menuTorrent release];
	
	_menuTorrent = nil;
}

- (NSMenu *) contextRowMenu
{
	return _contextRowMenu;
}

- (void) setPriorityForSelectedTorrents: (id) sender
{
    TorrentPriority priority;
    switch ([sender tag])
    {
        case ACTION_MENU_PRIORITY_HIGH_TAG:
            priority = NITorrentPriorityHigh;
            break;
        case ACTION_MENU_PRIORITY_NORMAL_TAG:
            priority = NITorrentPriorityNormal;
            break;
        case ACTION_MENU_PRIORITY_LOW_TAG:
            priority = NITorrentPriorityLow;
            break;
        default:
            NSAssert1(NO, @"Unknown priority: %d", [sender tag]);
    }
	NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
	for (Torrent *torrent in torrents)
		[[DownloadsController sharedDownloadsController] setPriority:torrent priority:priority response:nil];
}

- (void) setSpeedLimitGlobal: (id) sender
{
    BOOL upload = [sender menu] == _globalUploadSpeedLimitMenu;
        //    [fDefaults setInteger: [[sender representedObject] intValue] forKey: upload ? @"UploadLimit" : @"DownloadLimit"];
    NSInteger limit = [[sender representedObject] intValue]*1024;
    if (upload)
        [[DownloadsController sharedDownloadsController] 
         setGlobalUploadSpeedLimit:limit
         response:nil];
    else
        [[DownloadsController sharedDownloadsController] 
         setGlobalDownloadSpeedLimit:limit
         response:nil];
}

-(void) unsetSpeedLimitGlobal: (id) sender
{
    BOOL upload = [sender menu] == _globalUploadSpeedLimitMenu;
    CGFloat speed = 0;
    
    if (sender == _globalDownloadSpeedLimitMenuItem || sender == _globalUploadSpeedLimitMenuItem)
        speed = sender == _globalUploadSpeedLimitMenuItem?_savedGlobalUploadSpeedLimit:_savedGlobalDownloadSpeedLimit;

    if (upload)
        [[DownloadsController sharedDownloadsController] 
         setGlobalUploadSpeedLimit:speed
         response:nil];
    else
        [[DownloadsController sharedDownloadsController] 
         setGlobalDownloadSpeedLimit:speed
         response:nil];
}

-(IBAction)moveSelectedTorrentsData:(id)sender
{
    [[MoveDataController sharedMoveDataController] openMoveDataWindow:_window torrents:[_downloadsView selectedTorrents]];
}

#pragma mark -
#pragma mark NSMenuDelegate stuff

- (void) menuNeedsUpdate: (NSMenu *) menu
{
    if (menu == _groupMenu || menu == _groupMainMenu)
    {
        [menu removeAllItems];
		
        NSMenu * groupMenu;
		groupMenu = [[GroupsController groups] groupMenuWithTarget: self action: @selector(setGroup:) isSmall: NO];
        
        const NSInteger groupMenuCount = [groupMenu numberOfItems];
        for (NSInteger i = 0; i < groupMenuCount; i++)
        {
            NSMenuItem * item = [[groupMenu itemAtIndex: 0] retain];
            [groupMenu removeItemAtIndex: 0];
            [menu addItem: item];
            [item release];
        }
    }
    else if (menu == _globalUploadSpeedLimitMenu || menu == _globalDownloadSpeedLimitMenu)
    {
        if ([menu numberOfItems] > 4)
            return;
        
        const NSInteger speedLimitActionValue[] = { 5, 10, 20, 30, 40, 50, 75, 100, 150, 200, 250, 500, 750, 1000, 1500, 2000, -1 };
        
        NSMenuItem * item;
        for (NSInteger i = 0; speedLimitActionValue[i] != -1; i++)
        {
            item = [[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: NSLocalizedString(@"%d KB/s",
                                                                                                    "Action menu -> upload/download limit"), speedLimitActionValue[i]] action: @selector(setSpeedLimitGlobal:)
                                       keyEquivalent: @""];
            [item setTarget: self];
            [item setRepresentedObject: [NSNumber numberWithInt: speedLimitActionValue[i]]];
            [menu addItem: item];
            [item release];
        }
        
        if (_savedGlobalDownloadSpeedLimit == 0)
        {
            _savedGlobalDownloadSpeedLimit = speedLimitActionValue[0]*1024;
            

            [_globalDownloadSpeedLimitMenuItem setTitle: [NSString stringWithFormat: NSLocalizedString(@"Limit (%d KB/s)",
                                                                                    "Action menu -> upload/download limit"),
                                                      (NSInteger)_savedGlobalDownloadSpeedLimit/1024]];
        }
        
        if (_savedGlobalUploadSpeedLimit==0.0)
        {
            _savedGlobalUploadSpeedLimit = speedLimitActionValue[0]*1024;
            
            [_globalUploadSpeedLimitMenuItem setTitle: [NSString stringWithFormat: NSLocalizedString(@"Limit (%d KB/s)",
                                                                                    "Action menu -> upload/download limit"),
                                                    (NSInteger)_savedGlobalUploadSpeedLimit/1024]];
        }
        
    }
	else if (menu == _contextRowMenu || menu == _priorityMainMenu)
    {
		NSArray * torrents = [(TorrentTableView *)_downloadsView selectedTorrents];
		
		NSInteger hp, np, lp;
		
		TorrentPriority pp = [torrents count]>0?[[torrents objectAtIndex:0] priority]:-1;
		
		BOOL allSame = (pp != -1);
		
		for (Torrent *torrent in torrents)
		{
			if (pp != torrent.priority)
			{
				allSame = NO;
				break;
			}
		}
		
		if (allSame && [torrents count]>0)
		{
		
			const TorrentPriority priority = [[torrents objectAtIndex:0] priority];
        
			hp = priority == NITorrentPriorityHigh ? NSOnState : NSOffState;
        
			np = priority == NITorrentPriorityNormal ? NSOnState : NSOffState;
        
			lp = priority == NITorrentPriorityLow ? NSOnState : NSOffState;
		}
		else 
		{
			hp = np = lp = NSOffState;
		}
		
		NSMenuItem * item = [menu itemWithTag: ACTION_MENU_PRIORITY_HIGH_TAG];
		[item setState: hp];
        
		item = [menu itemWithTag: ACTION_MENU_PRIORITY_NORMAL_TAG];
		[item setState: np];
        
		item = [menu itemWithTag: ACTION_MENU_PRIORITY_LOW_TAG];
		[item setState: lp];
		

    }
	
    else;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem 
{
	SEL action = [menuItem action];
	
	BOOL canUseTable = [_window isKeyWindow] || [[menuItem menu] supermenu] != [NSApp mainMenu];
	
    if (action == @selector(toggleQuickLook:))
    {
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if ([[DownloadsController sharedDownloadsController] findLocation:torrent] != nil)
			{
				//text consistent with Finder
				NSString * title = [[QuickLookController sharedQuickLookController] isVisible] ?
				NSLocalizedString(@"Close Quick Look", "View menu -> Quick Look")
				:NSLocalizedString(@"Quick Look", "View menu -> Quick Look");
				[menuItem setTitle: title];

                return YES;
			}
        return NO;
    }
	
	//enable pause item
    if (action == @selector(stopSelectedTorrents:))
    {
        if ([_defaults boolForKey:NIForceStopKey])
            [menuItem setTitle:NSLocalizedString(@"Stop selected", "View menu -> Quick Look")];
        else 
            [menuItem setTitle:@"Pause selected"];

        if (!canUseTable)
            return NO;
		
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if (!(torrent.state == NITorrentStatePaused || torrent.state == NITorrentStateStopped))
                return YES;
        return NO;
    }

	//enable pause item
    if (action == @selector(resumeSelectedTorrents:))
    {
        if ([_defaults boolForKey:NIForceStopKey])
            [menuItem setTitle:NSLocalizedString(@"Start selected", "View menu -> Quick Look")];
        else 
            [menuItem setTitle:@"Resume selected"];
        
        if (!canUseTable)
            return NO;
		
        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if (torrent.state == NITorrentStatePaused || torrent.state == NITorrentStateStopped)
                return YES;
        return NO;
    }
	
	if (action == @selector(removeNoDeleteSelectedTorrents:) 
		|| action == @selector(checkSelectedTorrents:)
		|| action == @selector(setPriorityForSelectedTorrents:)
        || action == @selector(moveSelectedTorrentsData:))
    {
        return canUseTable && [_downloadsView numberOfSelectedRows] > 0;
    }

	if (action == @selector(revealSelectedTorrents:)
		|| action == @selector(removeDeleteSelectedTorrents:))
    {
        if(! (canUseTable && [_downloadsView numberOfSelectedRows] > 0))
			return NO;

        for (Torrent * torrent in [_downloadsView selectedTorrents])
            if ([[DownloadsController sharedDownloadsController] findLocation:torrent] != nil)
                return YES;
		
		return NO;
    }
	
	if (action == @selector(setGroup:))
    {
        BOOL checked = NO;
        
        NSInteger index = [menuItem tag];
		
		if (_menuTorrent == nil)
		{
			for (Torrent * torrent in [_downloadsView selectedTorrents])
			{
				
				NSInteger torrentGroupIndex = [[GroupsController groups] groupIndexForTorrent: torrent];
				if (index == torrentGroupIndex)
				{
					checked = YES;
					break;
				}
			}
		}
		else
		{
			NSInteger torrentGroupIndex = [[GroupsController groups] groupIndexForTorrent: _menuTorrent];
			if (index == torrentGroupIndex)
			{
				checked = YES;
			}
		}
        [menuItem setState: checked ? NSOnState : NSOffState];
		
        return canUseTable && (_menuTorrent != nil || [_downloadsView numberOfSelectedRows] > 0);
    }
	
	return YES;
}

#pragma mark -
#pragma mark NSWindowDelegate

- (NSRect) windowWillUseStandardFrame: (NSWindow *) window defaultFrame: (NSRect) defaultFrame
{
    //if auto size is enabled, the current frame shouldn't need to change
    NSRect frame = [_defaults boolForKey: NIAutoSizeKey] ? [window frame] : [self sizedWindowFrame];
    
    frame.size.width = WINDOW_REGULAR_WIDTH;
    return frame;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    if (frameSize.width<WINDOW_REGULAR_WIDTH)
        frameSize.width = WINDOW_REGULAR_WIDTH;
    return frameSize;
}
@end

@implementation Controller(Private)

- (void) setWindowSizeToFit
{
    if ([_defaults boolForKey: NIAutoSizeKey])
    {
        NSScrollView * scrollView = [_downloadsView enclosingScrollView];
        
        [scrollView setHasVerticalScroller: NO];
        [_window setFrame: [self sizedWindowFrame] display: YES animate: YES];
        [scrollView setHasVerticalScroller: YES];
    }
}

- (NSRect) sizedWindowFrame
{
    NSInteger groups = [_viewController countGroups];
    
    CGFloat heightChange = (GROUP_SEPARATOR_HEIGHT + [_downloadsView intercellSpacing].height) * groups
	+ ([_downloadsView rowHeight] + [_downloadsView intercellSpacing].height) * ([_downloadsView numberOfRows] - groups)
	- [[_downloadsView enclosingScrollView] frame].size.height;
    
    return [self windowFrameByAddingHeight: heightChange checkLimits: YES];
}

- (NSRect) windowFrameByAddingHeight: (CGFloat) height checkLimits: (BOOL) check
{
    NSScrollView * scrollView = [_downloadsView enclosingScrollView];
    
    //convert pixels to points
    NSRect windowFrame = [_window frame];
    NSSize windowSize = [scrollView convertSize: windowFrame.size fromView: nil];

    windowSize.height += height;
    
    if (check)
    {
        NSSize minSize = [scrollView convertSize: [_window minSize] fromView: nil];
        
        if (windowSize.height < minSize.height)
            windowSize.height = minSize.height;
        else
        {
            NSSize maxSize = [scrollView convertSize: [[_window screen] visibleFrame].size fromView: nil];

			CGFloat dockHeight = [[_window screen] frame].size.height - maxSize.height;
			CGFloat maxDelta = (windowFrame.origin.y>0?(windowFrame.origin.y-dockHeight+MENU_BAR_HEIGHT):0);
			CGFloat maxHeight = windowFrame.size.height+(maxDelta>0?maxDelta:0);
			
			if (maxSize.height > maxHeight)
				maxSize.height = maxHeight;
			
            if (windowSize.height > maxSize.height)
                windowSize.height = maxSize.height;
			
        }
    }
	
    //convert points to pixels
    windowSize = [scrollView convertSize: windowSize toView: nil];
	
    windowFrame.origin.y -= (windowSize.height - windowFrame.size.height);
    windowFrame.size.height = windowSize.height;
	
    return windowFrame;
}

- (void) updateForExpandCollape
{
    [self setWindowSizeToFit];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &DownloadsViewChangedContext)
    {
		[self setWindowSizeToFit];
    }
    else if (context == &GlobalSpeedLimitChangedContext)
    {
        BOOL isDownloadSpeedLimitSet = [DownloadsController sharedDownloadsController].globalDownloadSpeedLimit>0;
        BOOL isUploadSpeedLimitSet = [DownloadsController sharedDownloadsController].globalUploadSpeedLimit>0;
        [_globalUploadSpeedNoLimitMenuItem setState:!isUploadSpeedLimitSet?NSOnState:NSOffState];
        [_globalUploadSpeedLimitMenuItem setState:isUploadSpeedLimitSet?NSOnState:NSOffState];
        [_globalDownloadSpeedNoLimitMenuItem setState:!isDownloadSpeedLimitSet?NSOnState:NSOffState];
        [_globalDownloadSpeedLimitMenuItem setState:isDownloadSpeedLimitSet?NSOnState:NSOffState];
        if (isDownloadSpeedLimitSet)
        {
            _savedGlobalDownloadSpeedLimit = [DownloadsController sharedDownloadsController].globalDownloadSpeedLimit;
            [_globalDownloadSpeedLimitMenuItem setTitle: [NSString stringWithFormat: NSLocalizedString(@"Limit (%d KB/s)",
                                                                              "Action menu -> upload/download limit"),
                                 (NSInteger)_savedGlobalDownloadSpeedLimit/1024]];
        }
        
        if (isUploadSpeedLimitSet)
        {
            _savedGlobalUploadSpeedLimit = [DownloadsController sharedDownloadsController].globalUploadSpeedLimit;
            [_globalUploadSpeedLimitMenuItem setTitle: [NSString stringWithFormat: NSLocalizedString(@"Limit (%d KB/s)",
                                                                                                   "Action menu -> upload/download limit"),
                                                      (NSInteger)_savedGlobalUploadSpeedLimit/1024]];
        }
    }
    else if (context == &ConnectedContext)
    {
        [self connected];
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}
- (void) connected
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(connected) withObject:nil waitUntilDone:NO];
        return;
    }
    if ([DownloadsController sharedDownloadsController].connected)
        [_overlayWindow fadeOut];
    else if ([DownloadsController sharedDownloadsController].connecting)
        [_overlayWindow setImageAndMessage:[NSImage imageNamed: @"Loading.gif"] mainMessage:@"Connecting ..." message:nil];
    else
        [_overlayWindow setImageAndMessage:[NSImage imageNamed: @"Error-large.png"] mainMessage:@"Disconnected" message:[DownloadsController sharedDownloadsController].lastError];
}
@end
