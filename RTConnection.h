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

@class AMSession;

@interface RTConnection : NSObject 
{
	NSString    *hostName;
	int port;
	AMSession   *_proxy;
	BOOL        _connected;
	BOOL        _connecting;
    NSString    *error;
}
- (id)initWithHostPort:(NSString *)initHost port:(int)initPort proxy:(AMSession*) proxy;

- (BOOL) openStreams:(NSInputStream **)iStream oStream:(NSOutputStream **) oStream delegate:(id) delegate error:(NSString **) connectionError;

-(void) closeConnection;

-(void) openConnection:(void (^)(RTConnection *sender))handler;

@property (readonly) BOOL     connected;
@property (readonly) BOOL     connecting;
@property (assign)   NSString *error;
@end
