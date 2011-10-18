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

#import "DownloadsController.h"
#import "SynthesizeSingleton.h"
#import "Torrent.h"
#import "TorrentController.h"
#import "ProcessesController.h"
#import "PreferencesController.h"
#import "GroupsController.h"
#include <Growl/Growl.h>
#import "NSStringTorrentAdditions.h"

static NSString * ConnectedContext = @"ConnectedContext";

static NSString * ConnectingContext = @"ConnectingContext";

NSString* const NINotifyUpdateDownloads = @"NINotifyUpdateDownloads";

@interface DownloadsController(Private)

- (void)_updateList;

- (id<TorrentController>) _controller;

- (NSInteger) _processIndex;

- (VoidResponseBlock) _updateListResponse: (VoidResponseBlock) originalResponse errorFormat:(NSString*) errorFormat;

-(void) setError:(NSString*) fmt error:(NSString*) error;

@end

@implementation DownloadsController

SYNTHESIZE_SINGLETON_FOR_CLASS(DownloadsController);

@synthesize globalUploadSpeed           = _globalUploadSpeed;
@synthesize globalDownloadSpeed         = _globalDownloadSpeed;
@synthesize spaceLeft                   = _spaceLeft;
@synthesize globalDownloadSize          = _globalDownloadSize;
@synthesize globalUploadSize            = _globalUploadSize;
@synthesize globalRatio                 = _globalRatio;
@synthesize globalDownloadSpeedLimit    = _globalDownloadSpeedLimit;
@synthesize globalUploadSpeedLimit      = _globalUploadSpeedLimit;

@synthesize connected, connecting;

@dynamic lastError;
- (NSString *) lastError
{
    return [[self _controller] lastError];
}

-(id)init;
{
	self = [super init];
	if (self == nil)
		return nil;
	_downloads = [[[NSMutableArray alloc] init] retain];
	_defaults = [NSUserDefaults standardUserDefaults];
    _queue = [[NSOperationQueue alloc] init];
    [_queue retain];
	_deleteSound = [NSSound soundNamed: @"drag to trash"];
    [_deleteSound retain];
	return self;
}


-(void)dealloc
{
	[_downloads release];
    [_queue release];
    [_deleteSound release];
	[super dealloc];
}

#pragma mark -
#pragma mark public methods

-(void) startUpdates:(VoidResponseBlock) response;
{
	[_updateListTimer invalidate];
	[_updateGlobalsTimer invalidate];

    [(NSObject *)[self _controller] addObserver:self
                                     forKeyPath:@"connected"
                                        options:0
                                        context:&ConnectedContext];
    [(NSObject *)[self _controller] addObserver:self
                                     forKeyPath:@"connecting"
                                        options:0
                                        context:&ConnectingContext];
    
    
	__block DownloadsController *blockSelf = self;
	[[ProcessesController sharedProcessesController] openProcessForIndex:[self _processIndex] handler:^(NSString* error){
		if (response)
			response(error);
		
		if (error == nil)
		{
			[blockSelf _updateList];
			blockSelf->_updateListTimer = [NSTimer scheduledTimerWithTimeInterval:
                                           [blockSelf->_defaults integerForKey:NIRefreshRateKey]
                                                                           target:self 
                                                                         selector:@selector(_updateList) 
                                                                         userInfo:nil 
                                                                          repeats:YES];
			[blockSelf->_updateListTimer retain];
			[[NSRunLoop currentRunLoop] addTimer:blockSelf->_updateListTimer forMode:NSDefaultRunLoopMode];	
            
			[blockSelf updateGlobals];
			blockSelf->_updateGlobalsTimer = [NSTimer scheduledTimerWithTimeInterval:
                                              [blockSelf->_defaults integerForKey:NIUpdateGlobalsRateKey]
                                                                              target:self 
                                                                            selector:@selector(updateGlobals) 
                                                                            userInfo:nil 
                                                                             repeats:YES];
			[blockSelf->_updateGlobalsTimer retain];
			[[NSRunLoop currentRunLoop] addTimer:blockSelf->_updateGlobalsTimer forMode:NSDefaultRunLoopMode];
		}
	}];
}
-(void) stopUpdates;
{
	[_updateListTimer invalidate];
	[_updateGlobalsTimer invalidate];

    @try {
        [(NSObject *)[self _controller] removeObserver:self forKeyPath:@"connected"];
    }
    @catch (NSException *exception) {
            //ignore objserver removal exception
    }

    @try {
        [(NSObject *)[self _controller] removeObserver:self forKeyPath:@"connecting"];
    }
    @catch (NSException *exception) {
            //ignore objserver removal exception
    }
    
	
	ProcessesController* pc = [ProcessesController sharedProcessesController];
	
	for (NSInteger i=0;i<[pc count];i++)
	{
		NSInteger index =[pc indexForRow:i];
		[pc closeProcessForIndex:index];
	}
}

-(NSArray*) downloads;
{
	return _downloads;
}

#pragma mark -
#pragma mark concrete torrent methods

- (void) start:(Torrent *) torrent handler:(VoidResponseBlock) handler
{
	VoidResponseBlock r = [self _updateListResponse:handler errorFormat:@"Unable to start torrent: %@"];
	[[self _controller] start:torrent handler:r];
	[r release];
}

- (void) stop:(Torrent *) torrent force:(BOOL)force handler:(VoidResponseBlock) handler
{
	VoidResponseBlock r = [self _updateListResponse:handler errorFormat:@"Unable to stop torrent: %@"];
    if (force)
        [[self _controller] stop:torrent handler:r];
    else
        [[self _controller] pause:torrent handler:r];
	[r release];
}

- (void) add:(NSArray *) filesNames
{
    __block DownloadsController *blockSelf = self;
    [_queue addOperationWithBlock:^{
        for(NSString *file in filesNames)
        {
            NSURL* url = [NSURL fileURLWithPath:file];
            NSArray* urls = [NSArray arrayWithObjects:url, nil];
            
            NSURLRequest* request = [NSURLRequest requestWithURL:url];
            NSURLResponse *returningResponse = nil;
            NSError* connError = nil;
            NSData *rawTorrent = [NSURLConnection sendSynchronousRequest:request returningResponse:&returningResponse error:&connError];
            if (rawTorrent == nil)
            {
                [blockSelf setError:@"Unable to add torrent: %@" error:[connError localizedDescription]];
                continue;
            }
            Torrent *constructed = [Torrent torrentWithData:rawTorrent];
            NSInteger index = [[GroupsController groups] groupIndexForTorrentByRules:constructed];
            NSString *groupName = [[GroupsController groups] nameForIndex:index];
            NSString *folderName = [[GroupsController groups] usesCustomDownloadLocationForIndex:index]?
                                     [[GroupsController groups] customDownloadLocationForIndex:index]:
                                     nil;

            [[blockSelf _controller] add:rawTorrent 
                              start:[_defaults boolForKey:NIStartTransferWhenAddedKey] 
                              group:groupName
                             folder:folderName
                           response:^(NSString* error){ 
#warning memory leak here (recycleURLs)
                               if (error)
                               {
                                   [blockSelf setError:@"unable to add torrent: %@" error:error];
                                   return;
                               }
                               
                               if ([_defaults boolForKey:NITrashDownloadDescriptorsKey])
                               {
                                   [[NSWorkspace sharedWorkspace] recycleURLs: urls
                                                            completionHandler:^(NSDictionary *newURLs, NSError *error){
                                                                if (!error)
                                                                    [blockSelf->_deleteSound play];
                                                            }];
                               }
                               
                               [blockSelf _updateList];
                               [blockSelf updateGlobals];
                               [GrowlApplicationBridge
                                notifyWithTitle:@"Torrent added"
                                description:[NSString stringWithFormat:@"Torrent \"%@\", size %@, succesfully added", constructed.name, [NSString stringForFileSize:constructed.size]]
                                notificationName:@"INFO"
                                iconData:nil
                                priority:0
                                isSticky:NO
                                clickContext:nil];
                               
                           }];
            
        }
        
    }];
}

- (void) erase:(Torrent *) torrent withData:(BOOL) removeData response:(VoidResponseBlock) response
{
	__block DownloadsController *blockSelf = self;
	VoidResponseBlock r = [^(NSString* error){
		if (response)
			response(error);
		
		if (error)
		{
			[blockSelf setError:@"Unable to remove torrent:%@" error:error];
			return;
		}
		
		if (removeData)
		{
			NSString* dataLocation = [blockSelf findLocation:torrent];
			if (dataLocation)
			{
				NSURL* url = [NSURL fileURLWithPath:dataLocation];
				NSArray* urls = [NSArray arrayWithObjects:url, nil];
				[[NSWorkspace sharedWorkspace] recycleURLs: urls
										 completionHandler:^(NSDictionary *newURLs, NSError *error){
                                             if (error)
                                             {
                                                 NSLog(@"unable to trash file %@:",error);
                                                 NSError* removeError = nil;
                                                 [[NSFileManager defaultManager] removeItemAtPath:dataLocation error:&removeError];
                                                 if (removeError)
                                                     [self setError:@"Unable to delete file %@: " error:[removeError localizedDescription]];
                                                 else 
                                                     [blockSelf->_deleteSound play]; //play "trash" sound
                                                 
                                             }
                                             else
                                             {
                                                     //play "trash" sound
                                                 [blockSelf->_deleteSound play];					}
                                         }];
			}
			else 
				[self setError:@"Unable to delete torrent data: %@" error:@"cannot find torrent data"];

		}
		
		[blockSelf _updateList];
		[blockSelf updateGlobals];
	}copy];
	
	[[self _controller] erase:[torrent thash] response:r];
	[r release];
}

#pragma mark -
#pragma mark global state methods

- (void) setGlobalDownloadSpeedLimit:(NSInteger) speed response:(VoidResponseBlock) response
{
	__block DownloadsController *blockSelf = self;
	[[self _controller] setGlobalDownloadSpeedLimit:speed response:^(NSString* error){
		if (response)
			response(error);
		
		if (error)
        {
			[blockSelf setError:@"Unable to set global download speed limit: %@" error:error];
            return;
		}
        [blockSelf willChangeValueForKey:@"globalDownloadSpeedLimit"];
		_globalDownloadSpeedLimit = speed;
		[blockSelf didChangeValueForKey:@"globalDownloadSpeedLimit"];
	}];
}

- (void) setGlobalUploadSpeedLimit:(NSInteger) speed response:(VoidResponseBlock) response
{
	__block DownloadsController *blockSelf = self;
	[[self _controller] setGlobalUploadSpeedLimit:speed response:^(NSString* error){
		if (response)
			response(error);
		
		if (error)
        {
			[blockSelf setError:@"Unable to set global upload speed limit: %@" error:error];
            return;
		}
        [blockSelf willChangeValueForKey:@"globalUploadSpeedLimit"];
		_globalUploadSpeedLimit = speed;
		[blockSelf didChangeValueForKey:@"globalUploadSpeedLimit"];
	}];
}

- (void) reveal:(Torrent*) torrent
{
	NSString* location = [self findLocation:torrent];
	if (!location)
		location =  [[ProcessesController sharedProcessesController] localDownloadsFolderForIndex:[self _processIndex]];
	if (location)
	{
		NSURL * file = [NSURL fileURLWithPath: location];
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: [NSArray arrayWithObject: file]];
	
	}
}

-(void) setPriority:(Torrent *)torrent  priority:(TorrentPriority)priority response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response errorFormat:@"Unable to set priority for torrent: %@"];
	[[self _controller] setPriority:torrent priority:priority response:r];
	[r release];
}

- (void) setGroup:(Torrent *)torrent group:(NSString *) group response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response errorFormat:@"Unable to set group for torrent: %@"];
	[[self _controller] setGroup:torrent group:group response:r];
	[r release];
	
}

-(NSString*) findLocation:(Torrent *)torrent
{
	NSString * location = [[ProcessesController sharedProcessesController] localDownloadsFolderForIndex:[self _processIndex]];
	if (location)
	{
		NSMutableString* exactLocation = [NSMutableString stringWithCapacity:[location length]];
		NSArray* splittedPath = [torrent.dataLocation pathComponents];
		
		[exactLocation setString:location];
		
		NSFileManager* dm = [NSFileManager defaultManager];
		
		for(int i=[splittedPath count]-1;i>-1;i--) //we do not know where is file, so lets make some guesses
		{
			for (int ii = i;ii<[splittedPath count];ii++)
				[exactLocation appendFormat:@"/%@",[splittedPath objectAtIndex:ii]];
			
			if ([dm fileExistsAtPath:exactLocation])
				break;
			else
				[exactLocation setString:location];
			
		}
		
		if ([dm fileExistsAtPath:exactLocation] && ![exactLocation isEqualToString:location])
		{
			return exactLocation;
		}
	}
	return nil;
}

- (void) check:(Torrent*) torrent response:(VoidResponseBlock) response
{
	VoidResponseBlock r = [self _updateListResponse:response errorFormat:@"Unable to check hash for torrent: %@"];
	[[self _controller] check:torrent response:r];
	[r release];
}

- (void) updateGlobals
{
	NSString *path = [[ProcessesController sharedProcessesController] localDownloadsFolderForIndex:[self _processIndex]];
	if (path != nil)
    {
        NSError* error = nil;
        NSDictionary *attr = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:&error];
        if (error == nil)
            [self setSpaceLeft:[[attr objectForKey:NSFileSystemFreeSize] doubleValue]];
    }
    __block DownloadsController *blockSelf = self;
    [[self _controller] getGlobalDownloadSpeedLimit:^(NSNumber *number, NSString* error){
        if (error != nil)
        {
            [blockSelf setError:@"Unable to get global download speed limit: %@" error:error];
            return;
        }
        
        [blockSelf willChangeValueForKey:@"globalDownloadSpeedLimit"];
		_globalDownloadSpeedLimit = [number floatValue];
		[blockSelf didChangeValueForKey:@"globalDownloadSpeedLimit"];

        //update global max speed limits
        if ([_defaults boolForKey: NIGlobalSpeedLimitMaxAuto] 
                && _globalDownloadSpeedLimit == 0
                && [_defaults integerForKey:NIGlobalSpeedLimitMaxDownload]<_globalDownloadSpeed/1024)
                [_defaults setInteger:_globalDownloadSpeed/1024 forKey:NIGlobalSpeedLimitMaxDownload];
        
    }];

    [[self _controller] getGlobalUploadSpeedLimit:^(NSNumber *number, NSString* error){
        if (error != nil)
        {
            [blockSelf setError:@"Unable to get global upload speed limit: %@" error:error];
            return;
        }
        
        [blockSelf willChangeValueForKey:@"globalUploadSpeedLimit"];
		_globalUploadSpeedLimit = [number floatValue];
		[blockSelf didChangeValueForKey:@"globalUploadSpeedLimit"];

        //update global max speed limits
        if ([_defaults boolForKey: NIGlobalSpeedLimitMaxAuto] 
                && _globalUploadSpeedLimit == 0
                && [_defaults integerForKey:NIGlobalSpeedLimitMaxUpload]<_globalUploadSpeed/1024)
                [_defaults setInteger:_globalUploadSpeed/1024 forKey:NIGlobalSpeedLimitMaxUpload];
    }];
}

- (void) moveData:(Torrent *) torrent location:(NSString *) location handler:(VoidResponseBlock) handler
{
	VoidResponseBlock r = [self _updateListResponse:handler errorFormat:@"Unable to set location for torrent: %@"];
	[[self _controller] moveData:torrent location:location handler:r];
	[r release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if (context == &ConnectedContext)
    {
        [self setConnected:[self _controller].connected];
    }
    else if (context == &ConnectingContext)
    {
        [self setConnecting:[self _controller].connecting];
    }
    
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}
@end

@implementation DownloadsController(Private)
- (id<TorrentController>) _controller
{
	return [[ProcessesController sharedProcessesController] processForIndex:[self _processIndex]];
}

- (NSInteger) _processIndex
{
	return [[ProcessesController sharedProcessesController] indexForRow:0];
}

- (void)_updateList
{
	if (![[self _controller] connected])
		return;
	__block DownloadsController *blockSelf = self;
	ArrayResponseBlock response = [^(NSArray *array, NSString* error) {
		if (error != nil)
		{
			NSLog(@"update download list error: %@", error);
			return;
		}

		NSUInteger idx;
#warning multiple objects?
		Torrent* stored_obj;
		CGFloat globalUploadRate = 0.0;
		CGFloat globalDownloadRate = 0.0;
		CGFloat download = 0.0;
		CGFloat upload = 0.0;
		
		for (Torrent *obj in array)
		{
			idx = [blockSelf->_downloads indexOfObject:obj];
			if (idx ==  NSNotFound)
				[blockSelf->_downloads addObject:obj];
			else 
			{
				stored_obj = [blockSelf->_downloads objectAtIndex:idx];
				[stored_obj update:obj];
			}
            if (obj.state != NITorrentStateChecking)
            {
                globalUploadRate += [obj speedUpload];
                globalDownloadRate += [obj speedDownload];
                download+=obj.downloadRate;
                upload+=obj.uploadRate;
            }
		}
		
		//find removed torrents
		NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity: [blockSelf->_downloads count]];
		for (Torrent *obj in blockSelf->_downloads)
		{
			idx = [array indexOfObject:obj];
			if (idx ==  NSNotFound)
				[toRemove addObject:obj];
		}
		
		for (Torrent *obj in toRemove)
			[blockSelf->_downloads removeObject:obj];
		
		[[NSNotificationCenter defaultCenter] postNotificationName: NINotifyUpdateDownloads object: blockSelf];
		[blockSelf willChangeValueForKey:@"globalDownloadSpeed"];
		[blockSelf willChangeValueForKey:@"globalUploadSpeed"];
		[blockSelf willChangeValueForKey:@"globalDownloadSize"];
		[blockSelf willChangeValueForKey:@"globalUploadSize"];
		[blockSelf willChangeValueForKey:@"globalRatio"];
		_globalDownloadSpeed = globalDownloadRate;
		_globalUploadSpeed = globalUploadRate;
		_globalUploadSize = upload;
		_globalDownloadSize = download;
		_globalRatio = download==0?0:upload/download;
		[blockSelf didChangeValueForKey:@"globalDownloadSpeed"];
		[blockSelf didChangeValueForKey:@"globalUploadSpeed"];
		[blockSelf didChangeValueForKey:@"globalDownloadSize"];
		[blockSelf didChangeValueForKey:@"globalUploadSize"];
		[blockSelf didChangeValueForKey:@"globalRatio"];
	} copy];
	[[self _controller] list:response];
	[response release];
}

- (VoidResponseBlock) _updateListResponse: (VoidResponseBlock) originalResponse errorFormat:(NSString*) errorFormat
{
	__block DownloadsController *blockSelf = self;
	return [^(NSString* error){
		if (originalResponse)
			originalResponse(error);
		
		if (error)
			[blockSelf setError:errorFormat error:error];
		
		[blockSelf _updateList];
	}copy];
}

-(void) setError:(NSString*) fmt error:(NSString*) error;
{
	[GrowlApplicationBridge
	 notifyWithTitle:@"Error"
	 description:[NSString stringWithFormat:fmt, error]
	 notificationName:@"ERROR"
	 iconData:nil
	 priority:0
	 isSticky:NO
	 clickContext:nil];
	NSLog(fmt, error);
}
@end