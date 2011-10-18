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

#import "ProcessPreferencesController.h"
#import "ProcessesController.h"
#import "NIHostPort.h"
#import "DownloadsController.h"

#import "RTConnection.h"
#import "AMServer.h"
#import "AMSession.h"
#import "RTorrentController.h"

@interface ProcessPreferencesController(Private)

-(void)updateSelectedProcess;

- (void) downloadsPathClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info;

- (NSInteger) currentProcess;

- (void) runUpdates;
@end

@implementation ProcessPreferencesController

@synthesize useSSHKeyLogin, useSSHV2, host, port, useSSH, sshHost, sshPort, sshLocalPort, sshUser, sshPassword, groupsField, sshCompressionLevel, errorMessage, checking;

- (void) awakeFromNib
{
	pc = [ProcessesController sharedProcessesController];
	[self updateSelectedProcess];
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
				   modalForWindow: _window modalDelegate: self didEndSelector:
	 @selector(downloadsPathClosed:returnCode:contextInfo:) contextInfo: nil];
	
}

- (void) saveProcess: (id) sender
{
    [_window makeFirstResponder: nil];
    [[DownloadsController sharedDownloadsController] stopUpdates];
    [_testProcess closeConnection];
    [_testProcess release];
    [self setErrorMessage:nil];
    [self setChecking:YES];

    _testProcess = [[RTorrentController alloc] init];
    [_testProcess retain];
    
    AMSession* proxy = nil;
    NIHostPort *scgiHostPort = [NIHostPort parseHostPort:host defaultPort:5000];
    if (useSSH)
    {
        proxy = [[AMSession alloc] init];
        proxy.sessionName = @"test";
        
        
        proxy.remoteHost = scgiHostPort.host;
        proxy.remotePort = scgiHostPort.port;
        
        proxy.localPort = sshLocalPort;
        
        NIHostPort *sshHostPort = [NIHostPort parseHostPort:sshHost defaultPort:22];
        AMServer *server = [[AMServer alloc] init];
        server.host = sshHostPort.host;
        server.port = sshHostPort.port;
        server.username = sshUser;
        server.password = sshPassword;
        server.useSSHKeyLogin = useSSHKeyLogin;
        server.useSSHV2 = useSSHV2;
        server.compressionLevel = sshCompressionLevel;
        proxy.currentServer = server;
        proxy.maxAutoReconnectRetries = 1;
        proxy.autoReconnect = NO;
        [server release];
    }
    
    RTConnection* connection = [[RTConnection alloc] initWithHostPort:scgiHostPort.host port:scgiHostPort.port proxy:proxy];
    
    [_testProcess setConnection:connection];
    
    [connection release];
    [proxy release];
    
    [_testProcess setGroupField: groupsField];   
    
	[_testProcess openConnection: ^(NSString *error){
        if (error != nil)
        {
			NSLog(@"error: %@", error);
			[self setErrorMessage:error];
            [self setChecking:NO];
            [_testProcess closeConnection];
            [self runUpdates];
            return;
        }
        [_testProcess list:^(NSArray *array, NSString* error){
			[self setErrorMessage:error];
            [self setChecking:NO];
            [_testProcess closeConnection];
            if (error == nil)
            {
                NSInteger index = [self currentProcess];
                
                [pc setMaxReconnects:10 forIndex:index];
                
                NIHostPort *scgiHostPort = [NIHostPort parseHostPort:host defaultPort:5000];
                
                [pc setHost:scgiHostPort.host forIndex:index];
                
                [pc setPort:scgiHostPort.port forIndex:index];
                
                [pc setConnectionType:useSSH?@"SSH":@"Local" forIndex:index];
                
                NIHostPort *sshHostPort = [NIHostPort parseHostPort:sshHost defaultPort:22];
                
                [pc setSshHost:sshHostPort.host forIndex:index];
                
                [pc setSshPort:sshHostPort.port forIndex:index];
                
                [pc setSshUser:sshUser forIndex:index];
                
                [pc setSshPassword:sshPassword forIndex:index];
                
                [pc setSshUseKeyLogin:useSSHKeyLogin forIndex:index];
                
                [pc setGroupsField:groupsField forIndex:index];
                
                [pc setSshUseV2:useSSHV2 forIndex:index];
                
                [pc setSshCompressionLevel:sshCompressionLevel forIndex:index];
                
                [pc setSshLocalPort:sshLocalPort forIndex:index];
                
                [[ProcessesController sharedProcessesController] saveProcesses];
            }
            [self runUpdates];
        }];
    }];
}

-(void) dealloc
{
    [self setHost:nil];
    [self setSshHost:nil];
    [self setSshUser:nil];
    [self setSshPassword:nil];
    [_testProcess release];
    [super dealloc];
}
@end

@implementation ProcessPreferencesController(Private)
-(void)updateSelectedProcess
{
    NSInteger index = [self currentProcess];

	[self setHost:[NSString stringWithFormat:@"%@:%d",
                    [pc hostForIndex:index],
                    [pc portForIndex:index]==0?5000:[pc portForIndex:index]]];
	
	[self setGroupsField:[pc groupsFieldForIndex:index]];
		
	[_downloadsPathPopUp removeItemAtIndex:0];
	if ([pc localDownloadsFolderForIndex:index] == nil)
		[_downloadsPathPopUp insertItemWithTitle:@"" atIndex:0];
	else
	{
		[_downloadsPathPopUp insertItemWithTitle:[[NSFileManager defaultManager] displayNameAtPath: [pc localDownloadsFolderForIndex:index]] atIndex:0];
		
		NSString * path = [[pc localDownloadsFolderForIndex:index] stringByExpandingTildeInPath];
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
	
	[self setUseSSH:[[pc connectionTypeForIndex:index] isEqualToString:@"SSH"]];

    if ([pc sshPortForIndex:index] == 22)
            [self setSshHost:[pc sshHostForIndex:index]];
    else if ([pc sshHostForIndex:index] != nil)
        [self setSshHost:[NSString stringWithFormat:@"%@:%d",
                            [pc sshHostForIndex:index],
                            [pc sshPortForIndex:index]]];
    else;
		
	[self setSshUser: [pc sshUserForIndex:index]];
		
	[self setSshPassword: [pc sshPasswordForIndex:index]];
	
	[self setSshLocalPort: [pc sshLocalPortForIndex:index] == 0?5000:[pc sshLocalPortForIndex:index]];
	
	[self setUseSSHKeyLogin:[pc sshUseKeyLoginForIndex:index]];
    
    [self setSshCompressionLevel:[pc sshCompressionLevelForIndex:index]];
}

- (void) downloadsPathClosed: (NSOpenPanel *) openPanel returnCode: (int) code contextInfo: (void *) info
{
    if (code == NSOKButton)
    {
        NSInteger index = [self currentProcess];
		
		NSString * folder = [[openPanel filenames] objectAtIndex: 0];

		[pc setLocalDownloadsFolder:folder forIndex:index];
		
		[self updateSelectedProcess];
		
    }
}

- (NSInteger) currentProcess;
{
	if ([pc count]>0)
		return [pc indexForRow:0];
	else
		return [pc addProcess];
}

-(void) runUpdates
{
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(runUpdates) withObject:nil waitUntilDone:NO];
        return;
    }
    [[DownloadsController sharedDownloadsController] startUpdates:nil];
}
@end