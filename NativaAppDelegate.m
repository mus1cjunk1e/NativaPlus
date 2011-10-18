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

#import "NativaAppDelegate.h"
#import "DownloadsController.h"
#import "ProcessesController.h"
#import "PreferencesController.h"
#import "SetupAssistantController.h"

@interface NativaAppDelegate(Private)
    - (void)showMainWindow;
@end


@implementation NativaAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	if ([[ProcessesController sharedProcessesController] count]==0)
        [[SetupAssistantController sharedSetupAssistantController] openSetupAssistant:^(id sender){
            [self showMainWindow];
        }];
    else
    {
        [self showMainWindow];
    }
}

- (void) application: (NSApplication *) app openFiles: (NSArray *) fileNames
{
    [[DownloadsController sharedDownloadsController] add:fileNames];
}

- (BOOL) applicationShouldHandleReopen: (NSApplication *) app hasVisibleWindows: (BOOL) visibleWindows
{
	//hide window instead of close
    NSWindow * mainWindow = [NSApp mainWindow];
    if (!mainWindow || ![mainWindow isVisible])
        [window makeKeyAndOrderFront: nil];
    
    return NO;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[[DownloadsController sharedDownloadsController] stopUpdates]; 
}
@end

@implementation NativaAppDelegate(Private)
- (void)showMainWindow
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(showMainWindow) withObject:nil waitUntilDone:NO];
        return;
    }
    
    [window orderFront:nil];
    [[DownloadsController sharedDownloadsController] startUpdates:nil];
}
@end