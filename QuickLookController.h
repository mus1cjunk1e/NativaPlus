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
#import <Quartz/Quartz.h>
#import "TorrentTableView.h"

@interface QuickLookController : NSObject<QLPreviewPanelDataSource, QLPreviewPanelDelegate> 
{
	QLPreviewPanel		*_panel;
	TorrentTableView	*_view;
	NSWindow			*_window;
	BOOL				_isVisible;
	NSMutableArray		*_torrents;
}
@property BOOL isVisible;
+(QuickLookController*) sharedQuickLookController;
+(void) show;
-(void) beginPanel:(QLPreviewPanel*) panel window:(NSWindow*)window view:(TorrentTableView*) _downloadsView;
-(void) endPanel;
@end
