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

#import "SetupAssistantController.h"
#import "SynthesizeSingleton.h"
#import "NIHostPort.h"
#import "ProcessesController.h"

#import <netinet/in.h>

@interface SetupAssistantController(Private)
- (int) findFreePort:(int) startPort endPort:(int)endPort;
- (void) checkSettings:(BOOL) checkSSH checkSCGI:(BOOL) checkSCGI handler:(void (^)(BOOL success))handler;
- (void) downloadsPathClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info;
- (void) showError:(NSString *) error;
- (void) closeTestConnection;
@end

@implementation SetupAssistantController

@dynamic currentView;
@synthesize sshHost, sshUsername, sshPassword, useSSHKeyLogin, errorMessage, checking, sshLocalPort, scgiHost, openSetupAssistantHandler, localDownloadsFolder;
;

SYNTHESIZE_SINGLETON_FOR_CLASS(SetupAssistantController);

- (id) init
{
    if ((self = [super initWithWindowNibName: @"SetupAssistant"]))
    {
        pc = [ProcessesController sharedProcessesController];
        currentProcessIndex = [pc addProcess];
    }
    
    return self;
}

- (void) openSetupAssistant:(void (^)(id sender))handler
{
    [self setOpenSetupAssistantHandler:handler];
	NSWindow* window = [self window];
	if (![window isVisible])
        [window center];
	
    [window makeKeyAndOrderFront: nil];
}

- (void)awakeFromNib
{
    NSView *contentView = [[self window] contentView];
    [contentView setWantsLayer:YES];
    [self setCurrentView:startView];
    [contentView addSubview:[self currentView]];
    
    transition = [CATransition animation];
    [transition setType:kCATransitionPush];
    [transition setSubtype:kCATransitionFromLeft];
    
    NSDictionary *ani = [NSDictionary dictionaryWithObject:transition forKey:@"subviews"];
    [contentView setAnimations:ani];
}

- (void)setCurrentView:(NSView*)newView
{
    if (!currentView) {
        currentView = newView;
        return;
    }
    NSView *contentView = [[self window] contentView];
    [[contentView animator] replaceSubview:currentView with:newView];
    currentView = newView;
}

- (NSView*) currentView
{
    return currentView;
}

- (IBAction)showStartView:(id)sender
{
    useSSH = NO;
    [self setChecking:NO];
    [self setErrorMessage:nil];
    [transition setSubtype:kCATransitionFromLeft];
    [self setCurrentView:startView];
}
- (IBAction)showConfigureSSHView:(id)sender
{
    [self setChecking:NO];
    useSSH = NO;
    [transition setSubtype:kCATransitionFromRight];
    [self setCurrentView:configureSSHView];
    [[self window] makeFirstResponder:sshFirstResponder];
}
- (IBAction)showConfigureSCGIView:(id)sender
{
    [self setErrorMessage: nil];
    [transition setSubtype:kCATransitionFromRight];
    [self setCurrentView:configureSCGIView];
    [[self window] makeFirstResponder:scgiFirstResponder];
}
- (IBAction)checkSSH:(id)sender
{
    sshLocalPort = [self findFreePort:5000 endPort:5010];
    if (scgiHost == nil || [scgiHost isEqualToString:@""])
        [self setScgiHost: @"127.0.0.1:5000"];
    [self checkSettings:YES checkSCGI:NO handler:^(BOOL success){
        if (success)
        {
            useSSH = YES;
            [self showConfigureSCGIView:nil];
        }
    }];
}

- (IBAction)checkSCGI:(id)sender
{
    [self checkSettings:useSSH checkSCGI:YES handler:^(BOOL success){
        if (success)
        {
            [pc saveProcesses];
            [[self window] close];
            if (openSetupAssistantHandler != nil)
                openSetupAssistantHandler(self);
        }
    }];
}

    //show folder doalog for downloads path
- (void) downloadsPathShow: (id) sender
{
    NSOpenPanel * panel = [NSOpenPanel openPanel];
	
    [panel setPrompt: NSLocalizedString(@"Select", "Preferences -> Open panel prompt")];
    [panel setAllowsMultipleSelection: NO];
    [panel setCanChooseFiles: NO];
    [panel setCanChooseDirectories: YES];
    [panel setCanCreateDirectories: YES];
	
    [panel beginSheetForDirectory: nil file: nil types: nil
				   modalForWindow: [self window] modalDelegate: self didEndSelector:
	 @selector(downloadsPathClosed:returnCode:contextInfo:) contextInfo: nil];
	
}
@end
@implementation SetupAssistantController(Private)
-(int) findFreePort:(int) startPort endPort:(int)endPort
{
    CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM,
                            IPPROTO_TCP, 0, NULL, NULL);
	if (!socket)
	{
		NSLog(@"unable to create socket");
		return 0;
	}
    
	int fileDescriptor = CFSocketGetNative(socket);
    int reuse = false;
    
	if (setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR,
                   (void *)&reuse, sizeof(int)) != 0)
	{
        CFSocketInvalidate(socket);
        CFRelease(socket);
        socket = nil;
		NSLog(@"Unable to set socket options.");
		return 0;
	}
	
	struct sockaddr_in address;
	memset(&address, 0, sizeof(address));
	address.sin_len = sizeof(address);
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	CFDataRef addressData = nil;
    
    int resultPort = 0;
    
    for(int i=startPort;i<=endPort;i++)
    {
        address.sin_port = htons(i);
        addressData =
            CFDataCreate(NULL, (const UInt8 *)&address, sizeof(address));
        [(id)addressData autorelease];
        
        if (CFSocketSetAddress(socket, addressData) == kCFSocketSuccess)
        {
            resultPort = i;
            NSLog(@"port %d is free", i);
            break;
        }
        NSLog(@"port %d is busy", i);
    }

    CFSocketInvalidate(socket);
    CFRelease(socket);
    socket = nil;

    if (resultPort == 0)
        NSLog(@"Unable to bind socket to address.");

    return resultPort;
}
- (void) checkSettings:(BOOL) checkSSH checkSCGI:(BOOL) checkSCGI handler:(void (^)(BOOL success))handler;
{
    [[self window] makeFirstResponder: nil];
    [self setErrorMessage: nil];

    [pc closeProcessForIndex:currentProcessIndex];
    
    NIHostPort *scgiHostPort = [NIHostPort parseHostPort:scgiHost==nil?@"":scgiHost defaultPort:5000];
    
    NIHostPort *sshHostPort = [NIHostPort parseHostPort:sshHost==nil?@"":sshHost defaultPort:22];
    
        //test connection with only one reconnect
	int maxReconnects = ([pc maxReconnectsForIndex:currentProcessIndex] == 0?10:[pc maxReconnectsForIndex:currentProcessIndex]);
    
	[pc setMaxReconnects:0 forIndex:currentProcessIndex];
    
    [pc setHost:scgiHostPort.host forIndex:currentProcessIndex];
    
    [pc setPort:scgiHostPort.port forIndex:currentProcessIndex];
    
    [pc setConnectionType:checkSSH?@"SSH":@"Local" forIndex:currentProcessIndex];
    
    [pc setSshHost:sshHostPort.host forIndex:currentProcessIndex];
    
    [pc setSshPort:sshHostPort.port forIndex:currentProcessIndex];
    
    [pc setSshLocalPort:sshLocalPort forIndex:currentProcessIndex];
    
    [pc setSshUser:sshUsername forIndex:currentProcessIndex];
    
    [pc setSshPassword:sshPassword forIndex:currentProcessIndex];
    
    [pc setSshUseKeyLogin:useSSHKeyLogin forIndex:currentProcessIndex];

    [pc setSshUseV2:NO forIndex:currentProcessIndex];
        
    [pc setSshCompressionLevel:0 forIndex:currentProcessIndex];
    
    [pc setGroupsField:1 forIndex:currentProcessIndex];
    
    [pc setLocalDownloadsFolder:localDownloadsFolder forIndex:currentProcessIndex];
    
    [self setChecking:YES];
    [pc openProcessForIndex:currentProcessIndex handler:^(NSString *error){
        [pc setMaxReconnects:maxReconnects forIndex:currentProcessIndex];
        [self showError:error];
        
        if (checkSCGI)
        {
            [[pc processForIndex:currentProcessIndex] list:^(NSArray *array, NSString* error){
                [self setChecking:NO];
                [self showError:error];
                [self closeTestConnection];
                
                if (handler)
                    handler(error == nil);
                
            }];
        }
        else 
        {
            [self setChecking:NO];
            [self closeTestConnection];

            if (handler)
                handler(error == nil);
        }

    }];
}

- (void) downloadsPathClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info
{
    if (code == NSOKButton)
    {
		NSString * folder = [[openPanel filenames] objectAtIndex: 0];
        
		[self setLocalDownloadsFolder:folder];
		
        [_downloadsPathPopUp removeItemAtIndex:0];
        if (localDownloadsFolder == nil)
            [_downloadsPathPopUp insertItemWithTitle:@"" atIndex:0];
        else
        {
            [_downloadsPathPopUp insertItemWithTitle:[[NSFileManager defaultManager] displayNameAtPath: localDownloadsFolder] atIndex:0];
            
            NSString * path = [localDownloadsFolder stringByExpandingTildeInPath];
            NSImage * icon;
                //show a folder icon if the folder doesn't exist
            if ([[path pathExtension] isEqualToString: @""] && ![[NSFileManager defaultManager] fileExistsAtPath: path])
                icon = [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode('fldr')];
            else
                icon = [[NSWorkspace sharedWorkspace] iconForFile: path];
            
            [icon setSize: NSMakeSize(16.0, 16.0)];
            NSMenuItem* menuItem = [_downloadsPathPopUp itemAtIndex:0];
            [menuItem setImage:icon];
        }
        [_downloadsPathPopUp selectItemAtIndex: 0];
		
    }
}

- (void) showError:(NSString *) error
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(showError:) withObject:error waitUntilDone:NO];
        return;
    }
    NSLog(@"error: %@", error);
	[self setChecking:NO];
	[self setErrorMessage: error];
}

- (void) closeTestConnection
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(closeTestConnection) withObject:nil waitUntilDone:NO];
        return;
    }
    [pc closeProcessForIndex:currentProcessIndex];
}

@end
