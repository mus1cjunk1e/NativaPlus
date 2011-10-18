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
#import "Torrent.h"

extern NSString* const NINotifyUpdateDownloads;

@class RTorrentController, Torrent;

@interface DownloadsController : NSObject 
{
@private
	NSMutableArray	* _downloads;
	NSTimer			* _updateListTimer;
	NSTimer			* _updateGlobalsTimer;
	CGFloat			  _globalUploadSpeed;
	CGFloat			  _globalDownloadSpeed;
	CGFloat			  _spaceLeft;
	CGFloat			  _globalUploadSize;
	CGFloat			  _globalDownloadSize;
	CGFloat			  _globalRatio;
    CGFloat			  _globalUploadSpeedLimit;
    CGFloat			  _globalDownloadSpeedLimit;
	NSUserDefaults	* _defaults;
    NSOperationQueue	*_queue;
    BOOL              connected;
    BOOL              connecting;
    NSSound           *_deleteSound;
}
@property (assign)	CGFloat globalUploadSpeed;
@property (assign)	CGFloat globalDownloadSpeed;
@property (assign)	CGFloat spaceLeft;
@property (assign)	CGFloat globalDownloadSize;
@property (assign)	CGFloat globalUploadSize;
@property (assign)	CGFloat globalRatio;
@property (assign)	CGFloat globalDownloadSpeedLimit;
@property (assign)	CGFloat globalUploadSpeedLimit;

@property (assign) BOOL connected;
@property (assign) BOOL connecting;

@property (readonly) NSString *lastError;

+ (DownloadsController *)sharedDownloadsController;

-(void) startUpdates:(VoidResponseBlock) response;

-(void) stopUpdates;

-(NSArray*) downloads;

- (void) start:(Torrent *) torrent handler:(VoidResponseBlock) handler;

- (void) stop:(Torrent *) torrent force:(BOOL)force handler:(VoidResponseBlock) handler;

- (void) add:(NSArray *) filesNames;

- (void) erase:(Torrent *) torrent withData:(BOOL) removeData response:(VoidResponseBlock) response;

- (void) setGlobalDownloadSpeedLimit:(NSInteger) speed response:(VoidResponseBlock) response;

- (void) setGlobalUploadSpeedLimit:(NSInteger) speed response:(VoidResponseBlock) response;

- (void) reveal:(Torrent*) torrent;

- (void) setPriority:(Torrent *)torrent  priority:(TorrentPriority)priority response:(VoidResponseBlock) response;

- (void) setGroup:(Torrent *)torrent group:(NSString *) group response:(VoidResponseBlock) response;

-(NSString*) findLocation:(Torrent *)torrent;

- (void) check:(Torrent*) torrent response:(VoidResponseBlock) response;

- (void) updateGlobals;

- (void) moveData:(Torrent *) torrent location:(NSString *) location handler:(VoidResponseBlock) handler;
@end

