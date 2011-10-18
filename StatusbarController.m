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

#import "StatusbarController.h"
#import "DownloadsController.h"
#import "NSDataAdditions.h"
#import "NSStringTorrentAdditions.h"
#import "PreferencesController.h"

static NSString* GlobalUploadContext            = @"GlobalUploadContext";

static NSString* GlobalDownloadContext          = @"GlobalDownloadContext";

static NSString* SpaceLeftContext               = @"SpaceLeftContext";

static NSString* GlobalUploadSizeContext        = @"GlobalUploadSizeContext";

static NSString* GlobalRatioContext             = @"GlobalRatioContext";

static NSString* GlobalSpeedLimitChangedContext = @"GlobalSpeedLimitChangedContext";


typedef enum
{
    STATUS_RATIO_TOTAL_TAG = 0,
    STATUS_TRANSFER_TOTAL_TAG = 1,
    STATUS_SPACE_LEFT_TAG = 2
} statusTag;


#define STATUS_RATIO_TOTAL      @"RatioTotal"
#define STATUS_TRANSFER_TOTAL   @"TransferTotal"
#define STATUS_SPACE_LEFT		@"SpaceLeft"


@interface StatusbarController(Private)
- (void) resizeStatusButton;
- (void) changeStatusLabel;
@end

@implementation StatusbarController

@dynamic globalSpeedLimit;

- (id)init
{
    if (self = [super init]) 
	{
        _globalSpeedLimit = 0.01; //for some reason sider do not want set zero on start
    }
    return self;
}

-(void) dealloc
{
    [_currentObserver release];
    [super dealloc];
}
- (void)awakeFromNib
{
	[[DownloadsController sharedDownloadsController] addObserver:self
				forKeyPath:@"globalUploadSpeed"
				options:0
				context:&GlobalUploadContext];
	[[DownloadsController sharedDownloadsController] addObserver:self
				forKeyPath:@"globalDownloadContext"
				options:0
				context:&GlobalUploadContext];

    [[DownloadsController sharedDownloadsController] addObserver:self
                                                      forKeyPath:@"globalDownloadSpeedLimit"
                                                         options:0
                                                         context:&GlobalSpeedLimitChangedContext];
    
    [[DownloadsController sharedDownloadsController] addObserver:self
                                                      forKeyPath:@"globalUploadSpeedLimit"
                                                         options:0
                                                         context:&GlobalSpeedLimitChangedContext];
    
	[self changeStatusLabel];
	
}

-(void) setGlobalSpeedLimit: (double) value
{
    NSInteger uploadSpeed;
    NSInteger downloadSpeed;
    if (value == 100.0)
    {
        downloadSpeed = 0;
        uploadSpeed = 0;
    }
    else if (value == 0.0)
    {
        downloadSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMinDownload];
        uploadSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMinUpload];
    }
    else
    {
        downloadSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMaxDownload]/100*value;
        uploadSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMaxUpload]/100*value;
        if (downloadSpeed == 0)
            downloadSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMinDownload];
        if (uploadSpeed == 0)
            uploadSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMinUpload];
    }
    
    [[DownloadsController sharedDownloadsController] 
     setGlobalUploadSpeedLimit:uploadSpeed*1024
     response:nil];
    
    [[DownloadsController sharedDownloadsController] 
     setGlobalDownloadSpeedLimit:downloadSpeed*1024
     response:nil];
    
    _globalSpeedLimit = value;
}

-(double) globalSpeedLimit
{
    return _globalSpeedLimit;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &GlobalDownloadContext || context == &GlobalUploadContext)
    {
		CGFloat up = [DownloadsController sharedDownloadsController].globalUploadSpeed;
		CGFloat down = [DownloadsController sharedDownloadsController].globalDownloadSpeed;
        [_dowloadSpeedButton setTitle: [NSString stringForSpeed:down]];
        [_uploadSpeedButton setTitle: [NSString stringForSpeed:up]];
    }
	else if (context == &SpaceLeftContext)
    {
		[_statusButton setTitle:[NSString stringWithFormat: @"Space left: %@", [NSString stringForFileSize:[DownloadsController sharedDownloadsController].spaceLeft]]];
		[self resizeStatusButton];
    }
	else if (context == &GlobalUploadSizeContext)
    {
		[_statusButton setTitle:[NSString stringWithFormat: @"DL: %@ UL: %@", 
								 [NSString stringForFileSize:[DownloadsController sharedDownloadsController].globalDownloadSize],
								 [NSString stringForFileSize:[DownloadsController sharedDownloadsController].globalUploadSize]]];
        [self resizeStatusButton];
    }
	else if (context == &GlobalRatioContext)
    {
		[_statusButton setTitle:[NSString stringWithFormat: @"Ratio: %@", 
								 [NSString stringForRatio:[DownloadsController sharedDownloadsController].globalRatio]]];
        [self resizeStatusButton];
    }
	else if (context == &GlobalSpeedLimitChangedContext)
    {
            // compute global speed limit (UL+DL)
        double maxDownload = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMaxDownload]*1024;
        double maxUpload = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMaxUpload]*1024;
        double tmp=[DownloadsController sharedDownloadsController].globalDownloadSpeedLimit;
        double computedSpeedLimit = tmp>0?tmp:maxDownload;
        tmp=[DownloadsController sharedDownloadsController].globalUploadSpeedLimit;
        computedSpeedLimit += tmp>0?tmp:maxUpload;
        if (computedSpeedLimit == (maxUpload+maxDownload))
            [_globalSpeedLimitSlider setDoubleValue:100]; //no limit
        else
        {
                // max speed limit will be maxUL+maxDL
            double maxSpeedLimit = [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMaxUpload]*1024+
            [[NSUserDefaults standardUserDefaults] doubleForKey:NIGlobalSpeedLimitMaxDownload]*1024;
            
            [_globalSpeedLimitSlider setDoubleValue:100*(computedSpeedLimit/maxSpeedLimit)];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void) setStatusLabel: (id) sender
{
    NSString * statusLabel;
    switch ([sender tag])
    {
        case STATUS_RATIO_TOTAL_TAG:
            statusLabel = STATUS_RATIO_TOTAL;
            break;
        case STATUS_TRANSFER_TOTAL_TAG:
            statusLabel = STATUS_TRANSFER_TOTAL;
            break;
        case STATUS_SPACE_LEFT_TAG:
            statusLabel = STATUS_SPACE_LEFT;
            break;
        default:
            NSAssert1(NO, @"Unknown status label tag received: %d", [sender tag]);
            return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject: statusLabel forKey: @"StatusLabel"];
	[self changeStatusLabel];
}
@end

@implementation StatusbarController(Private)
- (void) resizeStatusButton
{
    [_statusButton sizeToFit];
    
    //width ends up being too long
    NSRect statusFrame = [_statusButton frame];
    statusFrame.size.width -= 25.0;
    
    CGFloat difference = NSMaxX(statusFrame) + 5.0 - [_globalSpeedLimitSlider frame].origin.x;
    if (difference > 0)
        statusFrame.size.width -= difference;
    
    [_statusButton setFrame: statusFrame];
}
- (void) changeStatusLabel;
{
	NSString *statusLabel = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusLabel"];
	NSUInteger tag;

	if (_currentObserver != nil)
		[[DownloadsController sharedDownloadsController] removeObserver:self forKeyPath:_currentObserver];
	
	if ([statusLabel isEqualToString:STATUS_TRANSFER_TOTAL])
	{
		_currentObserver = @"globalUploadSize";
		[[DownloadsController sharedDownloadsController] addObserver:self
														  forKeyPath:_currentObserver
															 options:0
															 context:&GlobalUploadSizeContext];
		[_statusButton setTitle:[NSString stringWithFormat: @"DL: %@ UL: %@", 
								 [NSString stringForFileSize:[DownloadsController sharedDownloadsController].globalDownloadSize],
								 [NSString stringForFileSize:[DownloadsController sharedDownloadsController].globalUploadSize]]];
		tag = STATUS_TRANSFER_TOTAL_TAG;
	}
	else if ([statusLabel isEqualToString:STATUS_RATIO_TOTAL])
	{
		_currentObserver = @"globalRatio";
		[[DownloadsController sharedDownloadsController] addObserver:self
														  forKeyPath:_currentObserver
															 options:0
															 context:&GlobalRatioContext];
		[_statusButton setTitle:[NSString stringWithFormat: @"Ratio: %@", 
								 [NSString stringForRatio:[DownloadsController sharedDownloadsController].globalRatio]]];
		NSMenuItem* item = [[_statusButton menu] itemAtIndex:0];
		[item setImage:[NSImage imageNamed: @"YingYangTemplate.png"]];
		tag = STATUS_RATIO_TOTAL_TAG;
	}
	else
	{
		_currentObserver = @"spaceLeft";
		[[DownloadsController sharedDownloadsController] addObserver:self
													  forKeyPath:_currentObserver
														 options:0
														 context:&SpaceLeftContext];
		[_statusButton setTitle:[NSString stringWithFormat: @"Space left: %@", [
								 NSString stringForFileSize:[DownloadsController sharedDownloadsController].spaceLeft]]];
		tag = STATUS_TRANSFER_TOTAL_TAG;
	}
	
	NSMenuItem* item0 = [[_statusButton menu] itemAtIndex:0];
	NSMenuItem* itemT = [[_statusButton menu] itemWithTag:tag];
	[item0 setImage:[itemT image]];

	[self resizeStatusButton];

	
}
@end
