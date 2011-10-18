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

@class RTorrentController;

@interface RTSCGIOperation : NSOperation<NSStreamDelegate> 
{
	NSOutputStream*				oStream;
	
	NSInputStream*				iStream;

	NSMutableData*				_responseData;
	
	NSString					*command;
	
	NSArray						*arguments;
	
	void (^handler)(id data, NSString* error);
	
    BOOL						_isExecuting;
	
	NSAutoreleasePool			*pool;
	
	id<RTorrentCommand>         operation;
	
	NSData						*_requestData;

	NSInteger					_writtenBytesCounter;
    
    RTorrentController          *controller;
}
@property (copy) void (^handler)(id data, NSString* error);

- (id)initWithCommand:(RTorrentController *)controller command:(NSString*)command arguments:(NSArray*)arguments handler:(void(^)(id data, NSString* error)) h;

- (id)initWithOperation:(RTorrentController *)controller operation:(id<RTorrentCommand>) operation;

@end
