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
#import "TorrentController.h"

@class ProcessDescriptor;

@interface ProcessesController : NSObject 
{
	NSMutableArray *_processes;
}
+ (ProcessesController *)sharedProcessesController;


-(NSInteger) count;

-(void) setName:(NSString *)name forIndex:(NSInteger) index;
-(NSString *) nameForIndex:(NSInteger) index;

-(void) setProcessType:(NSString *)type forIndex:(NSInteger) index;
-(NSString *) processTypeForIndex:(NSInteger) index;

-(void) setConnectionType:(NSString *)type forIndex:(NSInteger) index;
-(NSString *) connectionTypeForIndex:(NSInteger) index;

-(void) setHost:(NSString *)host forIndex:(NSInteger) index;
-(NSString *) hostForIndex:(NSInteger) index;

-(void) setPort:(NSInteger)port forIndex:(NSInteger) index;
-(NSInteger) portForIndex:(NSInteger) index;

-(void) setLocalDownloadsFolder:(NSString *)folder forIndex:(NSInteger) index;
-(NSString *) localDownloadsFolderForIndex:(NSInteger) index;

-(void) setSshHost:(NSString *)host forIndex:(NSInteger) index;
-(NSString *) sshHostForIndex:(NSInteger) index;

-(void) setSshPort:(NSInteger)port forIndex:(NSInteger) index;
-(NSInteger) sshPortForIndex:(NSInteger) index;

-(void) setSshLocalPort:(NSInteger)port forIndex:(NSInteger) index;
-(NSInteger) sshLocalPortForIndex:(NSInteger) index;

-(void) setSshUser:(NSString *)user forIndex:(NSInteger) index;
-(NSString *) sshUserForIndex:(NSInteger) index;

-(void) setSshPassword:(NSString *)password forIndex:(NSInteger) index;
-(NSString *) sshPasswordForIndex:(NSInteger) index;

-(void) setMaxReconnects:(NSInteger)maxReconnects forIndex:(NSInteger) index;
-(NSInteger) maxReconnectsForIndex:(NSInteger) index;

-(void) setGroupsField:(NSInteger)groupsField forIndex:(NSInteger) index;
-(NSInteger) groupsFieldForIndex:(NSInteger) index;

-(void) setSshUseKeyLogin:(BOOL)sshUseKeyLogin forIndex:(NSInteger) index;
-(BOOL) sshUseKeyLoginForIndex:(NSInteger) index;

-(void) setSshUseV2:(BOOL)sshUseV2 forIndex:(NSInteger) index;
-(BOOL) sshUseV2ForIndex:(NSInteger) index;

-(void) setSshCompressionLevel:(NSInteger)sshCompressionLevel forIndex:(NSInteger) index;
-(NSInteger) sshCompressionLevelForIndex:(NSInteger) index;

- (NSInteger) indexForRow: (NSInteger) row;

-(NSInteger) addProcess;

-(void)saveProcesses;

-(void) openProcessForIndex:(NSInteger) index handler:(void (^)(NSString *error)) handler;

-(void) closeProcessForIndex:(NSInteger) index;

-(id<TorrentController>) processForIndex:(NSInteger) index;
@end
