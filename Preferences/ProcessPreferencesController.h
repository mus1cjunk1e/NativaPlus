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

#import <Cocoa/Cocoa.h>

@class ProcessesController, RTorrentController;

@interface ProcessPreferencesController : NSObject
{
	IBOutlet NSPopUpButton	*_downloadsPathPopUp;
	
	IBOutlet NSWindow		*_window;
	
	ProcessesController		*pc;
	
	BOOL					useSSHKeyLogin;
    
    BOOL					useSSHV2;
    
    NSString                *host;
    
    NSInteger               port;
    
    BOOL                    useSSH;
    
    NSString                *sshHost;
    
    NSInteger               sshPort;
    
    NSString                *sshUser;
    
    NSString                *sshPassword;
    
    NSInteger               groupsField;
    
    NSInteger               sshCompressionLevel;
    
    NSInteger               sshLocalPort;

    NSString                *errorMessage;
    
    BOOL                    checking;
    
    RTorrentController      *_testProcess;
}

@property BOOL              useSSHKeyLogin;

@property BOOL              useSSHV2;

@property (retain) NSString *host;

@property NSInteger         port;

@property BOOL              useSSH;

@property (retain) NSString *sshHost;

@property NSInteger         sshPort;

@property NSInteger         sshLocalPort;

@property (retain) NSString *sshUser;

@property (retain) NSString *sshPassword;

@property NSInteger         groupsField;

@property NSInteger         sshCompressionLevel;

@property (retain) NSString *errorMessage;

@property (assign) BOOL     checking;

- (void) downloadsPathShow: (id) sender;

- (void) saveProcess: (id) sender;
@end
