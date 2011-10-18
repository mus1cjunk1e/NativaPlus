/******************************************************************************
 * $Id: PrefsController.m 9844 2010-01-01 21:12:04Z livings124 $
 *
 * Copyright (c) 2005-2010 Transmission authors and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *****************************************************************************/

#import "PreferencesController.h"
#import "SynthesizeSingleton.h"

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_PROCESSES   @"TOOLBAR_PROCESSES"
#define TOOLBAR_GROUPS		@"TOOLBAR_GROUPS"
#define TOOLBAR_BANDWIDTH		@"TOOLBAR_BANDWIDTH"

NSString* const NITrashDownloadDescriptorsKey       = @"TrashOriginalTransferDescriptor";
NSString* const NIStartTransferWhenAddedKey         = @"StartTransferWhenAdded";
NSString* const NIProcessListKey                    = @"ProcessList";
NSString* const NIFilterKey                         = @"Filter";
NSString* const NIRefreshRateKey                    = @"RefreshRateKey";
NSString* const NIUpdateGlobalsRateKey              = @"UpdateGlobalsRateKey";
NSString* const NIAutoSizeKey                       = @"AutoSize";
NSString* const NIForceStopKey                      = @"ForceStop";
NSString* const NIGlobalSpeedLimitMaxDownload       = @"GlobalSpeedLimitMaxDownload";
NSString* const NIGlobalSpeedLimitMaxUpload         = @"GlobalSpeedLimitMaxUpload";
NSString* const NIGlobalSpeedLimitMinDownload       = @"GlobalSpeedLimitMinDownload";
NSString* const NIGlobalSpeedLimitMinUpload         = @"GlobalSpeedLimitMinUpload";
NSString* const NIGlobalSpeedLimitMaxAuto           = @"GlobalSpeedLimitMaxAuto";

@interface PreferencesController (Private)

- (void) setPrefView: (id) sender;

@end

@implementation PreferencesController
SYNTHESIZE_SINGLETON_FOR_CLASS(PreferencesController);

- (id) init
{
    if ((self = [super initWithWindowNibName: @"PreferencesWindow"]))
    {
        
		_defaults = [NSUserDefaults standardUserDefaults];
    }
    
    return self;
}

- (void) awakeFromNib
{
    NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier: @"Preferences Toolbar"];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [toolbar setSizeMode: NSToolbarSizeModeRegular];
    [toolbar setSelectedItemIdentifier: TOOLBAR_GENERAL];
    [[self window] setToolbar: toolbar];
    [toolbar release];
    
    [self setPrefView: nil];
}

//NSToolbarDelegate stuff
- (NSToolbarItem *) toolbar: (NSToolbar *) toolbar itemForItemIdentifier: (NSString *) ident willBeInsertedIntoToolbar: (BOOL) flag
{
    NSToolbarItem * item = [[NSToolbarItem alloc] initWithItemIdentifier: ident];

    if ([ident isEqualToString: TOOLBAR_GENERAL])
    {
        [item setLabel: NSLocalizedString(@"General", "Preferences -> toolbar item title")];
        [item setImage: [NSImage imageNamed: NSImageNamePreferencesGeneral]];
        [item setTarget: self];
        [item setAction: @selector(setPrefView:)];
        [item setAutovalidates: NO];
    }
    else if ([ident isEqualToString: TOOLBAR_PROCESSES])
    {
        [item setLabel: NSLocalizedString(@"rTorrent", "Preferences -> toolbar item title")];
        [item setImage: [NSImage imageNamed: NSImageNameComputer]];
        [item setTarget: self];
        [item setAction: @selector(setPrefView:)];
        [item setAutovalidates: NO];
    }
    else if ([ident isEqualToString: TOOLBAR_GROUPS])
    {
        [item setLabel: NSLocalizedString(@"Groups", "Preferences -> toolbar item title")];
        [item setImage: [NSImage imageNamed: @"Groups.png"]];
        [item setTarget: self];
        [item setAction: @selector(setPrefView:)];
        [item setAutovalidates: NO];
    }
    else if ([ident isEqualToString: TOOLBAR_BANDWIDTH])
    {
        [item setLabel: NSLocalizedString(@"Bandwidth", "Preferences -> toolbar item title")];
        [item setImage: [NSImage imageNamed: @"Bandwidth.png"]];
        [item setTarget: self];
        [item setAction: @selector(setPrefView:)];
        [item setAutovalidates: NO];
    }
    else
    {
        [item release];
        return nil;
    }

    return [item autorelease];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects: TOOLBAR_GENERAL, TOOLBAR_PROCESSES, TOOLBAR_GROUPS, TOOLBAR_BANDWIDTH, nil];
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarAllowedItemIdentifiers: toolbar];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarAllowedItemIdentifiers: toolbar];
}

-(void) openPreferences:(NIPReferencesView) view;
{
	NSWindow* window = [self window];
	if (![window isVisible])
        [window center];
	
    [window makeKeyAndOrderFront: nil];
	if (view == NIPReferencesViewProcesses)
	{
		[[NSUserDefaults standardUserDefaults] setObject: TOOLBAR_PROCESSES forKey: @"SelectedPrefView"];
		[self setPrefView: nil];
	}
}

- (void) setAutoSize: (id) sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName: @"AutoSizeSettingChange" object: self];
}
@end

@implementation PreferencesController (Private)

- (void) setPrefView: (id) sender
{
    NSString * identifier;
    if (sender)
    {
        identifier = [sender itemIdentifier];
        [[NSUserDefaults standardUserDefaults] setObject: identifier forKey: @"SelectedPrefView"];
    }
    else
        identifier = [[NSUserDefaults standardUserDefaults] stringForKey: @"SelectedPrefView"];
    
    NSView * view;
    if ([identifier isEqualToString: TOOLBAR_PROCESSES])
        view = _processesView;
	else if ([identifier isEqualToString: TOOLBAR_GROUPS])
        view = _groupsView;
	else if ([identifier isEqualToString: TOOLBAR_BANDWIDTH])
        view = _bandwidthView;
    else
    {
        identifier = TOOLBAR_GENERAL; //general view is the default selected
        view = _generalView;
    }
    
    [[[self window] toolbar] setSelectedItemIdentifier: identifier];
    
    NSWindow * window = [self window];
    if ([window contentView] == view)
        return;
    
    NSRect windowRect = [window frame];
    float difference = ([view frame].size.height - [[window contentView] frame].size.height) * [window userSpaceScaleFactor];
    windowRect.origin.y -= difference;
    windowRect.size.height += difference;
    
    [view setHidden: YES];
    [window setContentView: view];
    [window setFrame: windowRect display: YES animate: YES];
    [view setHidden: NO];
    
    //set title label
    if (sender)
        [window setTitle: [sender label]];
    else
    {
        NSToolbar * toolbar = [window toolbar];
        NSString * itemIdentifier = [toolbar selectedItemIdentifier];
        for (NSToolbarItem * item in [toolbar items])
            if ([[item itemIdentifier] isEqualToString: itemIdentifier])
            {
                [window setTitle: [item label]];
                break;
            }
    }
}
@end
