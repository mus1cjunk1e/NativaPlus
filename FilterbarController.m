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

#import "FilterbarController.h"
#import "Torrent.h"
#import "SynthesizeSingleton.h"
#import "PreferencesController.h"
#import "FilterButton.h"

static NSString *FILTER_ALL = @"All";
static NSString *FILTER_DOWNLOAD = @"Downloading";
static NSString *FILTER_UPLOAD = @"Uploading";
static NSString *FILTER_STOP = @"Paused";
static NSString *FILTER_CHECKING = @"Checking";
static NSString *FILTER_ACTIVE = @"Active";

@interface FilterbarController(Private)
-(void)_updateFilter;
-(NSButton*) _currentButton;
@end

@implementation FilterbarController
SYNTHESIZE_SINGLETON_FOR_CLASS(FilterbarController);

@synthesize stateFilter = _stateFilter;

- (void)awakeFromNib 
{
	[self setFilter:[self _currentButton]];
}

//resets filter and sorts torrents
- (void) setFilter: (id) sender
{
	NSButton * prevFilterButton = [self _currentButton];
    
    if (sender != prevFilterButton)
    {
        [prevFilterButton setState: NSOffState];
        [(NSButton *)sender setState: NSOnState];
		
		NSString *filterType;
		
        if (sender == _downloadFilterButton)
            filterType = FILTER_DOWNLOAD;
        else if (sender == _stopFilterButton)
            filterType = FILTER_STOP;
        else if (sender == _seedFilterButton)
            filterType = FILTER_UPLOAD;
		else if (sender == _checkingFilterButton)
			filterType = FILTER_CHECKING;
		else if (sender == _activeFilterButton)
			filterType = FILTER_ACTIVE;
        else
            filterType = FILTER_ALL;
		
        [[NSUserDefaults standardUserDefaults] setObject: filterType forKey: NIFilterKey];
    }
    else
        [(NSButton *)sender setState: NSOnState];
	
    [self _updateFilter];
}

- (void) setSearch: (id) sender
{
	[self _updateFilter];
}


@end

@implementation FilterbarController(Private)
-(NSButton*) _currentButton
{
    NSString *currentFilterName = [[NSUserDefaults standardUserDefaults] objectForKey: NIFilterKey];

    if ([currentFilterName isEqualToString: FILTER_STOP])
        return _stopFilterButton;
    else if ([currentFilterName isEqualToString: FILTER_UPLOAD])
        return _seedFilterButton;
    else if ([currentFilterName isEqualToString: FILTER_DOWNLOAD])
        return _downloadFilterButton;
	else if ([currentFilterName isEqualToString: FILTER_CHECKING])
		return _checkingFilterButton;
	else if ([currentFilterName isEqualToString: FILTER_ACTIVE])
		return _activeFilterButton;
    else
        return _allFilterButton;
}

-(void)_updateFilter
{
	NSString *currentFilterName = [[NSUserDefaults standardUserDefaults] objectForKey: NIFilterKey];
	NSString * searchString = [_searchFilterField stringValue];
	NSString* filter;
	
    if ([currentFilterName isEqualToString: FILTER_STOP])
        filter = [NSString stringWithFormat: @"(SELF.state == %d || SELF.state == %d)",NITorrentStateStopped,NITorrentStatePaused];
    else if ([currentFilterName isEqualToString: FILTER_UPLOAD])
        filter = [NSString stringWithFormat: @"SELF.state == %d",NITorrentStateSeeding];
    else if ([currentFilterName isEqualToString: FILTER_DOWNLOAD])
        filter = [NSString stringWithFormat: @"SELF.state == %d",NITorrentStateLeeching];
	else if ([currentFilterName isEqualToString: FILTER_CHECKING])
		filter = [NSString stringWithFormat: @"SELF.state == %d",NITorrentStateChecking];
    else if ([currentFilterName isEqualToString: FILTER_ACTIVE])
		filter = [NSString stringWithFormat: @"((SELF.speedDownload > 0 || SELF.speedUpload > 0) AND (SELF.state == %d || SELF.state == %d))",NITorrentStateSeeding,NITorrentStateLeeching];
	else
        filter = nil;
	
	filter = [NSString stringWithFormat: @"%@ SELF.name like[c] \"*%@*\"", filter == nil?@"":[NSString stringWithFormat: @"%@ AND ", filter], searchString];
	NSLog(@"filter: %@", filter);
	
	[FilterbarController sharedFilterbarController].stateFilter = [NSPredicate predicateWithFormat:filter];
}
@end