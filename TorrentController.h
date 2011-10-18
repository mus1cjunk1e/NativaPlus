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
#import "RTorrentCommand.h"
#import "Torrent.h"

@protocol TorrentController<NSObject>

@property BOOL connected;

@property BOOL connecting;

- (void) list:(ArrayResponseBlock) response;

- (void) start:(Torrent *)torrent handler:(VoidResponseBlock) handler;

- (void) stop:(Torrent *)torrent handler:(VoidResponseBlock) handler;

- (void) add:(NSData *)rawTorrent start:(BOOL) start group:(NSString*) group folder:(NSString*) folder response:(VoidResponseBlock) response;

- (void) erase:(NSString *) hash response:(VoidResponseBlock) response;

- (void) setGlobalDownloadSpeedLimit:(int) speed response:(VoidResponseBlock) response;

- (void) setGlobalUploadSpeedLimit:(int) speed response:(VoidResponseBlock) response;

- (void) getGlobalDownloadSpeedLimit:(NumberResponseBlock) response;

- (void) getGlobalUploadSpeedLimit:(NumberResponseBlock) response;

- (void) setPriority:(Torrent *)torrent  priority:(TorrentPriority)priority response:(VoidResponseBlock) response;

- (void) setGroup:(Torrent *)torrent group:(NSString *) group response:(VoidResponseBlock) response;

- (void) openConnection:(VoidResponseBlock) response;

- (void) closeConnection;

- (void) check:(Torrent *)torrent response:(VoidResponseBlock) response;

- (void) pause:(Torrent *) hash handler:(VoidResponseBlock) handler;

- (void) moveData:(Torrent *) hash location:(NSString *) location handler:(VoidResponseBlock) handler;

- (NSString *) lastError;
@end

