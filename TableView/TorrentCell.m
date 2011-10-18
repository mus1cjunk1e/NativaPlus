/******************************************************************************
 * $Id: TorrentCell.m 9844 2010-01-01 21:12:04Z livings124 $
 *
 * Copyright (c) 2006-2010 Transmission authors and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *****************************************************************************/

#import "TorrentCell.h"
#import "GroupsController.h"
#import "NSStringTorrentAdditions.h"
#import "ProgressGradients.h"
#import "Torrent.h"
#import "TorrentTableView.h"
#import "DownloadsController.h"
#import "PreferencesController.h"

#define BAR_HEIGHT 12.0

#define IMAGE_SIZE_REG 32.0
#define ERROR_IMAGE_SIZE 20.0

#define NORMAL_BUTTON_WIDTH 14.0

#define PRIORITY_ICON_WIDTH 14.0
#define PRIORITY_ICON_HEIGHT 14.0

//ends up being larger than font height
#define HEIGHT_TITLE 16.0
#define HEIGHT_STATUS 12.0

#define PADDING_HORIZONTAL 3.0
#define PADDING_BETWEEN_IMAGE_AND_TITLE 5.0
#define PADDING_BETWEEN_IMAGE_AND_BAR 7.0
#define PADDING_BETWEEN_TITLE_AND_PRIORITY 4.0
#define PADDING_ABOVE_TITLE 4.0
#define PADDING_BETWEEN_TITLE_AND_PROGRESS 1.0
#define PADDING_BETWEEN_PROGRESS_AND_BAR 2.0
#define PADDING_BETWEEN_BAR_AND_STATUS 2.0

#define PIECES_TOTAL_PERCENT 0.6

#define MAX_PIECES (18*18)

@interface TorrentCell (Private)

- (void) drawBar: (NSRect) barRect;
- (void) drawRegularBar: (NSRect) barRect;
- (void) drawPiecesBar: (NSRect) barRect;

- (NSRect) rectForTitleWithString: (NSAttributedString *) string inBounds: (NSRect) bounds;
- (NSRect) rectForProgressWithStringInBounds: (NSRect) bounds;
- (NSRect) rectForStatusWithStringInBounds: (NSRect) bounds;
- (NSRect) barRectForBounds: (NSRect) bounds;

- (NSRect) controlButtonRectForBounds: (NSRect) bounds;
- (NSRect) revealButtonRectForBounds: (NSRect) bounds;

- (NSAttributedString *) attributedTitle;
- (NSAttributedString *) attributedStatusString: (NSString *) string;

- (NSString *) buttonString;
- (NSString *) statusString;
- (NSString *) torrentStatusString;

- (void) drawImage: (NSImage *) image inRect: (NSRect) rect; //use until 10.5 dropped

- (NSString *) torrentProgressString;

@end

@implementation TorrentCell

//only called once and the main table is always needed, so don't worry about releasing
- (id) init
{
    if ((self = [super init]))
	{
        fDefaults = [NSUserDefaults standardUserDefaults];
        
        NSMutableParagraphStyle * paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [paragraphStyle setLineBreakMode: NSLineBreakByTruncatingTail];
        
        fTitleAttributes = [[NSMutableDictionary alloc] initWithCapacity: 3];
        [fTitleAttributes setObject: [NSFont messageFontOfSize: 12.0] forKey: NSFontAttributeName];
        [fTitleAttributes setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];
        
        fStatusAttributes = [[NSMutableDictionary alloc] initWithCapacity: 3];
        [fStatusAttributes setObject: [NSFont messageFontOfSize: 9.0] forKey: NSFontAttributeName];
        [fStatusAttributes setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];
        
        [paragraphStyle release];
        
        fBluePieceColor = [[NSColor colorWithCalibratedRed: 0.0 green: 0.4 blue: 0.8 alpha: 1.0] retain];
        fBarBorderColor = [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.2] retain];
    }
	return self;
}

- (NSRect) iconRectForBounds: (NSRect) bounds
{
    return NSMakeRect(NSMinX(bounds) + PADDING_HORIZONTAL, floor(NSMidY(bounds) - IMAGE_SIZE_REG * 0.5),
                        IMAGE_SIZE_REG, IMAGE_SIZE_REG);
}

- (NSUInteger) hitTestForEvent: (NSEvent *) event inRect: (NSRect) cellFrame ofView: (NSView *) controlView
{
    NSPoint point = [controlView convertPoint: [event locationInWindow] fromView: nil];
    
    if (NSMouseInRect(point, [self controlButtonRectForBounds: cellFrame], [controlView isFlipped])
        || NSMouseInRect(point, [self revealButtonRectForBounds: cellFrame], [controlView isFlipped]
		|| NSMouseInRect(point, [self groupButtonRectForBounds: cellFrame], [controlView isFlipped])))
        return NSCellHitContentArea | NSCellHitTrackableArea;
    
    return NSCellHitContentArea;
}

+ (BOOL) prefersTrackingUntilMouseUp
{
    return YES;
}

- (BOOL) trackMouse: (NSEvent *) event inRect: (NSRect) cellFrame ofView: (NSView *) controlView untilMouseUp: (BOOL) flag
{
	fTracking = YES;
    
    [self setControlView: controlView];
    
    NSPoint point = [controlView convertPoint: [event locationInWindow] fromView: nil];
    
    const NSRect controlRect= [self controlButtonRectForBounds: cellFrame];
    const BOOL checkControl = NSMouseInRect(point, controlRect, [controlView isFlipped]);
    
    const NSRect revealRect = [self revealButtonRectForBounds: cellFrame];
    const BOOL checkReveal = NSMouseInRect(point, revealRect, [controlView isFlipped]);
	
	const NSRect groupRect = [self groupButtonRectForBounds: cellFrame];
    const BOOL checkGroup = NSMouseInRect(point, groupRect, [controlView isFlipped]);

//		for some reason it is not working
//    [(TorrentTableView *)controlView removeButtonTrackingAreas];

    while ([event type] != NSLeftMouseUp)
    {
        point = [controlView convertPoint: [event locationInWindow] fromView: nil];

        if (checkGroup)
        {
            const BOOL inGroupButton = NSMouseInRect(point, groupRect, [controlView isFlipped]);
            if (fMouseDownGroupButton != inGroupButton)
            {
                fMouseDownGroupButton = inGroupButton;
                [controlView setNeedsDisplayInRect: cellFrame];
            }
        }
        else if (checkControl)
        {
            const BOOL inControlButton = NSMouseInRect(point, controlRect, [controlView isFlipped]);
            if (fMouseDownControlButton != inControlButton)
            {
                fMouseDownControlButton = inControlButton;
                [controlView setNeedsDisplayInRect: cellFrame];
            }
        }
        else if (checkReveal)
        {
            const BOOL inRevealButton = NSMouseInRect(point, revealRect, [controlView isFlipped]);
            if (fMouseDownRevealButton != inRevealButton)
            {
                fMouseDownRevealButton = inRevealButton;
                [controlView setNeedsDisplayInRect: cellFrame];
            }
        }
        else;
        
        //send events to where necessary
        if ([event type] == NSMouseEntered || [event type] == NSMouseExited)
            [NSApp sendEvent: event];
        event = [[controlView window] nextEventMatchingMask:
				 (NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask)];
    }

    fTracking = NO;
	
    if (fMouseDownControlButton)
    {
        fMouseDownControlButton = NO;
        
        [(TorrentTableView *)controlView toggleControlForTorrent: [self representedObject]];
    }
    else if (fMouseDownRevealButton)
    {
        fMouseDownRevealButton = NO;
        [controlView setNeedsDisplayInRect: cellFrame];
		[[DownloadsController sharedDownloadsController] reveal:[self representedObject]];
    }
    else;
//		for some reason it is not working
//    [controlView updateTrackingAreas];
    
    return YES;
}

- (void) addTrackingAreasForView: (NSView *) controlView inRect: (NSRect) cellFrame withUserInfo: (NSDictionary *) userInfo
            mouseLocation: (NSPoint) mouseLocation
{
    NSTrackingAreaOptions options = NSTrackingEnabledDuringMouseDrag | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways;
    
    //control button
    NSRect controlButtonRect = [self controlButtonRectForBounds: cellFrame];
    NSTrackingAreaOptions controlOptions = options;
    if (NSMouseInRect(mouseLocation, controlButtonRect, [controlView isFlipped]))
    {
        controlOptions |= NSTrackingAssumeInside;
        [(TorrentTableView *)controlView setControlButtonHover: [[userInfo objectForKey: @"Row"] integerValue]];
    }
    
    NSMutableDictionary * controlInfo = [userInfo mutableCopy];
    [controlInfo setObject: @"Control" forKey: @"Type"];
    NSTrackingArea * area = [[NSTrackingArea alloc] initWithRect: controlButtonRect options: controlOptions owner: controlView
                                userInfo: controlInfo];
    [controlView addTrackingArea: area];
    [controlInfo release];
    [area release];

    //reveal button
    NSRect revealButtonRect = [self revealButtonRectForBounds: cellFrame];
    NSTrackingAreaOptions revealOptions = options;
    if (NSMouseInRect(mouseLocation, revealButtonRect, [controlView isFlipped]))
    {
        revealOptions |= NSTrackingAssumeInside;
        [(TorrentTableView *)controlView setRevealButtonHover: [[userInfo objectForKey: @"Row"] integerValue]];
    }
    
    NSMutableDictionary * revealInfo = [userInfo mutableCopy];
    [revealInfo setObject: @"Reveal" forKey: @"Type"];
    area = [[NSTrackingArea alloc] initWithRect: revealButtonRect options: revealOptions owner: controlView userInfo: revealInfo];
    [controlView addTrackingArea: area];
    [revealInfo release];
    [area release];
 
	//group button
	NSRect groupButtonRect = [self groupButtonRectForBounds: cellFrame];
	NSTrackingAreaOptions groupOptions = options;
	if (NSMouseInRect(mouseLocation, groupButtonRect, [controlView isFlipped]))
	{
		groupOptions |= NSTrackingAssumeInside;
		[(TorrentTableView *)controlView setGroupButtonHover: [[userInfo objectForKey: @"Row"] integerValue]];
	}
	
	NSMutableDictionary * groupInfo = [userInfo mutableCopy];
	[groupInfo setObject: @"Group" forKey: @"Type"];
	area = [[NSTrackingArea alloc] initWithRect: groupButtonRect options: groupOptions owner: controlView userInfo: groupInfo];
	[controlView addTrackingArea: area];
	[groupInfo release];
	[area release];
}

- (void) setControlHover: (BOOL) hover
{
    fHoverControl = hover;
}

- (void) setGroupHover: (BOOL) hover
{
    fHoverGroup = hover;
}

- (void) setRevealHover: (BOOL) hover
{
    fHoverReveal = hover;
}

- (void) drawInteriorWithFrame: (NSRect) cellFrame inView: (NSView *) controlView
{
    Torrent * torrent = [self representedObject];
    
    //group coloring
    const NSRect iconRect = [self iconRectForBounds: cellFrame];
	
	const BOOL error = ([torrent error] != nil);
    
    //icon
    [self drawImage: [torrent icon] inRect: iconRect];
	
    //error badge
    if (error)
    {
        NSRect errorRect = NSMakeRect(NSMaxX(iconRect) - ERROR_IMAGE_SIZE, NSMaxY(iconRect) - ERROR_IMAGE_SIZE,
                                        ERROR_IMAGE_SIZE, ERROR_IMAGE_SIZE);
        [self drawImage: [NSImage imageNamed: NSImageNameCaution] inRect: errorRect];
    }
    
    //text color
    NSColor * titleColor, * statusColor;
    if ([self backgroundStyle] == NSBackgroundStyleDark)
        titleColor = statusColor = [NSColor whiteColor];
    else
    {
        titleColor = [NSColor controlTextColor];
        statusColor = [NSColor darkGrayColor];
    }
    
    [fTitleAttributes setObject: titleColor forKey: NSForegroundColorAttributeName];
    [fStatusAttributes setObject: statusColor forKey: NSForegroundColorAttributeName];
    
    //title
    NSAttributedString * titleString = [self attributedTitle];
    NSRect titleRect = [self rectForTitleWithString: titleString inBounds: cellFrame];
    [titleString drawInRect: titleRect];
    
    //priority icon
    if ([torrent priority] != NITorrentPriorityNormal)
    {
        NSImage * priorityImage = [torrent priority] == NITorrentPriorityHigh ? [NSImage imageNamed: @"PriorityHigh.png"]
                                                                    : [NSImage imageNamed: @"PriorityLow.png"];
        NSRect priorityRect = NSMakeRect(NSMaxX(titleRect) + PADDING_BETWEEN_TITLE_AND_PRIORITY,
                                        NSMidY(titleRect) - PRIORITY_ICON_HEIGHT  * 0.5,
                                        PRIORITY_ICON_WIDTH, PRIORITY_ICON_HEIGHT);
        
        [self drawImage: priorityImage inRect: priorityRect];
    }
    
    //progress
	NSAttributedString * progressString = [self attributedStatusString: [self torrentProgressString]];
    NSRect progressRect = [self rectForProgressWithStringInBounds: cellFrame];
        
    [progressString drawInRect: progressRect];
    
    //bar
    [self drawBar: [self barRectForBounds: cellFrame]];
    
    //control button
    NSString * controlImageSuffix;
    if (fMouseDownControlButton)
        controlImageSuffix = @"On.png";
    else if (!fTracking && fHoverControl)
        controlImageSuffix = @"Hover.png";
    else
        controlImageSuffix = @"Off.png";

	//group button
	NSInteger groupIndex = [[GroupsController groups] groupIndexForTorrent:torrent]; 
	NSImage *groupImage;
	
    if (!fTracking && fHoverGroup)
        groupImage = [[GroupsController groups] hoverImageForIndex:groupIndex];
    else
        groupImage = [[GroupsController groups] imageForIndex:groupIndex];
	
	[self drawImage: groupImage inRect: [self groupButtonRectForBounds: cellFrame]];
	
    NSImage * controlImage;
    if (torrent.state == NITorrentStatePaused || torrent.state == NITorrentStateStopped)
        controlImage = [NSImage imageNamed: [@"Resume" stringByAppendingString: controlImageSuffix]];
    else
		controlImage = [NSImage imageNamed: [[[NSUserDefaults standardUserDefaults] boolForKey:NIForceStopKey]?@"Stop":@"Pause" stringByAppendingString: controlImageSuffix]];
    
    [self drawImage: controlImage inRect: [self controlButtonRectForBounds: cellFrame]];
    
    //reveal button
    NSString * revealImageString;
    if (fMouseDownRevealButton)
        revealImageString = @"RevealOn.png";
    else if (!fTracking && fHoverReveal)
        revealImageString = @"RevealHover.png";
    else
        revealImageString = @"RevealOff.png";
    
    NSImage * revealImage = [NSImage imageNamed: revealImageString];
    [self drawImage: revealImage inRect: [self revealButtonRectForBounds: cellFrame]];
    
    //status
	NSAttributedString * statusString = [self attributedStatusString: [self statusString]];
    [statusString drawInRect: [self rectForStatusWithStringInBounds: cellFrame]];
}

- (NSRect) groupButtonRectForBounds: (NSRect) bounds
{
    NSRect result;
    result.size.height = NORMAL_BUTTON_WIDTH;
    result.size.width = NORMAL_BUTTON_WIDTH;
    result.origin.x = NSMaxX(bounds) - 3.0 * (PADDING_HORIZONTAL + NORMAL_BUTTON_WIDTH);
    
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE + HEIGHT_TITLE - (NORMAL_BUTTON_WIDTH - BAR_HEIGHT) * 0.5;

	result.origin.y += PADDING_BETWEEN_TITLE_AND_PROGRESS + HEIGHT_STATUS + PADDING_BETWEEN_PROGRESS_AND_BAR;
    
    return result;
}
@end

@implementation TorrentCell (Private)

- (void) drawBar: (NSRect) barRect
{
    const CGFloat piecesBarPercent = [(TorrentTableView *)[self controlView] piecesBarPercent];
    if (piecesBarPercent > 0.0)
    {
        NSRect piecesBarRect, regularBarRect;
        NSDivideRect(barRect, &piecesBarRect, &regularBarRect, floor(NSHeight(barRect) * PIECES_TOTAL_PERCENT * piecesBarPercent),
                    NSMaxYEdge);
        
        [self drawRegularBar: regularBarRect];
        [self drawPiecesBar: piecesBarRect];
    }
    else
    {
//        [[self representedObject] setPreviousFinishedPieces: nil];
        
        [self drawRegularBar: barRect];
    }
    
    [fBarBorderColor set];
    [NSBezierPath strokeRect: NSInsetRect(barRect, 0.5, 0.5)];
}

- (void) drawRegularBar: (NSRect) barRect
{
    Torrent * torrent = [self representedObject];
    
    NSRect haveRect, missingRect;
    NSDivideRect(barRect, &haveRect, &missingRect, round([torrent progress] * NSWidth(barRect)), NSMinXEdge);
    
    if (!NSIsEmptyRect(haveRect))
    {
        switch (torrent.state) 
        {
            case NITorrentStateChecking:
                [[ProgressGradients progressYellowGradient] drawInRect: haveRect angle: 90];
                break;
            case NITorrentStateSeeding:
                [[ProgressGradients progressGreenGradient] drawInRect: haveRect angle: 90];
                break;
            case NITorrentStatePaused:
            case NITorrentStateStopped:
                [[ProgressGradients progressGrayGradient] drawInRect: haveRect angle: 90];
                break;
            default:
                [[ProgressGradients progressBlueGradient] drawInRect: haveRect angle: 90];
                break;
        }
    }
    
//    if (![torrent allDownloaded])
//    {
//        const CGFloat widthRemaining = round(NSWidth(barRect) * [torrent progressLeft]);
//        
//        NSRect wantedRect;
//        NSDivideRect(missingRect, &wantedRect, &missingRect, widthRemaining, NSMinXEdge);
//        
//        //not-available section
//        if ([torrent isActive] && ![torrent isChecking] && [torrent availableDesired] < 1.0
//            && [fDefaults boolForKey: @"DisplayProgressBarAvailable"])
//        {
//            NSRect unavailableRect;
//            NSDivideRect(wantedRect, &wantedRect, &unavailableRect, round(NSWidth(wantedRect) * [torrent availableDesired]),
//                        NSMinXEdge);
//            
//            [[ProgressGradients progressRedGradient] drawInRect: unavailableRect angle: 90];
//        }
//        
//        //remaining section
//        [[ProgressGradients progressWhiteGradient] drawInRect: wantedRect angle: 90];
//    }
    
    //unwanted section
//    if (!NSIsEmptyRect(missingRect))
//    {
//        if (![torrent isMagnet])
//            [[ProgressGradients progressLightGrayGradient] drawInRect: missingRect angle: 90];
//        else
//            [[ProgressGradients progressRedGradient] drawInRect: missingRect angle: 90];
//    }
}

- (void) drawPiecesBar: (NSRect) barRect
{
//    Torrent * torrent = [self representedObject];
//    
//    NSInteger pieceCount = MIN([torrent pieceCount], MAX_PIECES);
//    float * piecesPercent = malloc(pieceCount * sizeof(float));
//    [torrent getAmountFinished: piecesPercent size: pieceCount];
//    
//    NSBitmapImageRep * bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: nil
//                                    pixelsWide: pieceCount pixelsHigh: 1 bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES
//                                    isPlanar: NO colorSpaceName: NSCalibratedRGBColorSpace bytesPerRow: 0 bitsPerPixel: 0];
//    
//    NSIndexSet * previousFinishedIndexes = [torrent previousFinishedPieces];
//    NSMutableIndexSet * finishedIndexes = [NSMutableIndexSet indexSet];
//    
//    for (NSInteger i = 0; i < pieceCount; i++)
//    {
//        NSColor * pieceColor;
//        if (piecesPercent[i] == 1.0f)
//        {
//            if (previousFinishedIndexes && ![previousFinishedIndexes containsIndex: i])
//                pieceColor = [NSColor orangeColor];
//            else
//                pieceColor = fBluePieceColor;
//            [finishedIndexes addIndex: i];
//        }
//        else
//            pieceColor = [[NSColor whiteColor] blendedColorWithFraction: piecesPercent[i] ofColor: fBluePieceColor];
//        
//        //it's faster to just set color instead of checking previous color
//        [bitmap setColor: pieceColor atX: i y: 0];
//    }
//    
//    free(piecesPercent);
//    
//    [torrent setPreviousFinishedPieces: [finishedIndexes count] > 0 ? finishedIndexes : nil]; //don't bother saving if none are complete
//    
//    //actually draw image
//    [bitmap drawInRect: barRect];
//    [bitmap release];
}

- (NSRect) rectForTitleWithString: (NSAttributedString *) string inBounds: (NSRect) bounds
{
    NSRect result;
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE;
    result.origin.x = NSMinX(bounds) + PADDING_HORIZONTAL
                        + IMAGE_SIZE_REG + PADDING_BETWEEN_IMAGE_AND_TITLE;
    
    result.size.height = HEIGHT_TITLE;
    result.size.width = 0;
    result.size.width = NSMaxX(bounds) - NSMinX(result) - PADDING_HORIZONTAL;

    if ([[self representedObject] priority] != NITorrentPriorityNormal)
    {
        result.size.width -= PRIORITY_ICON_WIDTH + PADDING_BETWEEN_TITLE_AND_PRIORITY;
        result.size.width = MIN(NSWidth(result), [string size].width); //only need to force it smaller for the priority icon
    }
    
    return result;
}

- (NSRect) rectForProgressWithStringInBounds: (NSRect) bounds
{
    NSRect result;
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE + HEIGHT_TITLE + PADDING_BETWEEN_TITLE_AND_PROGRESS;
    result.origin.x = NSMinX(bounds) + PADDING_HORIZONTAL + IMAGE_SIZE_REG + PADDING_BETWEEN_IMAGE_AND_TITLE;
    
    result.size.height = HEIGHT_STATUS;
    result.size.width = 0;
    result.size.width = NSMaxX(bounds) - NSMinX(result) - PADDING_HORIZONTAL;
    
    return result;
}

- (NSRect) rectForStatusWithStringInBounds: (NSRect) bounds
{
    NSRect result;
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE + HEIGHT_TITLE + PADDING_BETWEEN_TITLE_AND_PROGRESS + HEIGHT_STATUS
                        + PADDING_BETWEEN_PROGRESS_AND_BAR + BAR_HEIGHT + PADDING_BETWEEN_BAR_AND_STATUS;
    result.origin.x = NSMinX(bounds) + PADDING_HORIZONTAL + IMAGE_SIZE_REG + PADDING_BETWEEN_IMAGE_AND_TITLE;
    
    result.size.height = HEIGHT_STATUS;
    result.size.width = 0;
    result.size.width = NSMaxX(bounds) - NSMinX(result) - PADDING_HORIZONTAL;
    
    return result;
}

- (NSRect) barRectForBounds: (NSRect) bounds
{
    NSRect result;
    result.size.height = BAR_HEIGHT;
    result.origin.x = NSMinX(bounds) + IMAGE_SIZE_REG + PADDING_BETWEEN_IMAGE_AND_BAR;
    
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE + HEIGHT_TITLE;

	result.origin.y += PADDING_BETWEEN_TITLE_AND_PROGRESS + HEIGHT_STATUS + PADDING_BETWEEN_PROGRESS_AND_BAR;
    
    result.size.width = floor(NSMaxX(bounds) - result.origin.x - PADDING_HORIZONTAL - 3.0 * (PADDING_HORIZONTAL + NORMAL_BUTTON_WIDTH));
    
    return result;
}

- (NSRect) controlButtonRectForBounds: (NSRect) bounds
{
    NSRect result;
    result.size.height = NORMAL_BUTTON_WIDTH;
    result.size.width = NORMAL_BUTTON_WIDTH;
    result.origin.x = NSMaxX(bounds) - 2.0 * (PADDING_HORIZONTAL + NORMAL_BUTTON_WIDTH);
    
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE + HEIGHT_TITLE - (NORMAL_BUTTON_WIDTH - BAR_HEIGHT) * 0.5;
    
	result.origin.y += PADDING_BETWEEN_TITLE_AND_PROGRESS + HEIGHT_STATUS + PADDING_BETWEEN_PROGRESS_AND_BAR;
    
    return result;
}

- (NSRect) revealButtonRectForBounds: (NSRect) bounds
{
    NSRect result;
    result.size.height = NORMAL_BUTTON_WIDTH;
    result.size.width = NORMAL_BUTTON_WIDTH;
    result.origin.x = NSMaxX(bounds) - (PADDING_HORIZONTAL + NORMAL_BUTTON_WIDTH);
    
    result.origin.y = NSMinY(bounds) + PADDING_ABOVE_TITLE + HEIGHT_TITLE - (NORMAL_BUTTON_WIDTH - BAR_HEIGHT) * 0.5;

	result.origin.y += PADDING_BETWEEN_TITLE_AND_PROGRESS + HEIGHT_STATUS + PADDING_BETWEEN_PROGRESS_AND_BAR;
    
    return result;
}

- (NSAttributedString *) attributedTitle
{
    NSString * title = [[self representedObject] name];
    return [[[NSAttributedString alloc] initWithString: title attributes: fTitleAttributes] autorelease];
}

- (NSAttributedString *) attributedStatusString: (NSString *) string
{
    return [[[NSAttributedString alloc] initWithString: string attributes: fStatusAttributes] autorelease];
}

- (NSString *) buttonString
{
    Torrent * torrent = [self representedObject];
	
	if (fMouseDownRevealButton || (!fTracking && fHoverReveal))
        return NSLocalizedString(@"Show the data file in Finder", "Torrent cell -> button info");
    else if (fMouseDownGroupButton || (!fTracking && fHoverGroup))
        return [NSString stringWithFormat:@"\"%@\"", torrent.groupName == nil? NSLocalizedString(@"No Group", "Group table row"):torrent.groupName];
    else if (fMouseDownControlButton || (!fTracking && fHoverControl))
    {
        if (torrent.state == NITorrentStatePaused || torrent.state == NITorrentStateStopped)
        {
            if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
                return NSLocalizedString(@"Resume the transfer right away", "Torrent cell -> button info");
            else
                return NSLocalizedString(@"Resume the transfer", "Torrent cell -> button info");
        }
        else
            return NSLocalizedString([[NSUserDefaults standardUserDefaults] boolForKey:NIForceStopKey]?@"Stop the transfer":@"Pause the transfer", "Torrent Table -> tooltip");
    }
    else
		return nil;
}

- (NSString *) statusString
{
    NSString * buttonString;
    if ((buttonString = [self buttonString]))
        return buttonString;
    else
		return [self torrentStatusString];
}

- (void) drawImage: (NSImage *) image inRect: (NSRect) rect
{
	[image drawInRect: rect fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0 respectFlipped: YES hints: nil];
}

- (NSString *) torrentStatusString
{
    Torrent *torrent = [self representedObject];
	NSString * string;
	
	if (torrent.error != nil)
		string = NSLocalizedString(torrent.error, "Torrent -> status string");
	else
	{
		switch (torrent.state)
		{
			case NITorrentStateStopped:
				string = NSLocalizedString(@"Stopped", "Torrent -> status string");
				break;

			case NITorrentStatePaused:
				string = NSLocalizedString(@"Paused", "Torrent -> status string");
				break;
				
			case NITorrentStateLeeching:
				if ((torrent.totalPeersSeed + torrent.totalPeersLeech + torrent.totalPeersDisconnected) != 1)
					string = [NSString stringWithFormat: NSLocalizedString(@"Downloading from %d of %d peers",
																	   "Torrent -> status string"), torrent.totalPeersSeed, torrent.totalPeersSeed + torrent.totalPeersLeech + torrent.totalPeersDisconnected];
				else
					string = [NSString stringWithFormat: NSLocalizedString(@"Downloading from %d of 1 peer",
																	   "Torrent -> status string"), torrent.totalPeersSeed];
				break;
			case NITorrentStateSeeding:
				if ((torrent.totalPeersLeech+torrent.totalPeersDisconnected) != 1)
					string = [NSString stringWithFormat: NSLocalizedString(@"Seeding to %d of %d peers", "Torrent -> status string"),
							  torrent.totalPeersLeech, torrent.totalPeersLeech+torrent.totalPeersDisconnected];
				else
					string = [NSString stringWithFormat: NSLocalizedString(@"Seeding to %d of 1 peer", "Torrent -> status string"),
							  torrent.totalPeersLeech];
				break;
			case NITorrentStateChecking:
				string = NSLocalizedString(@"Checking", "Torrent -> status string");
				break;
			default:
				NSAssert1(NO, @"Unknown state: %d", torrent.state);
				break;
		}
	}    
    //append even if error
	switch (torrent.state) 
	{
	case NITorrentStateLeeching:
            string = [string stringByAppendingFormat: @" - %@: %@, %@: %@",
					  NSLocalizedString(@"DL", "Torrent -> status string"), [NSString stringForSpeed: torrent.speedDownload],
					  NSLocalizedString(@"UL", "Torrent -> status string"), [NSString stringForSpeed: torrent.speedUpload]];
			break;
	case NITorrentStateSeeding:
            string = [string stringByAppendingFormat: @" - %@: %@",
					  NSLocalizedString(@"UL", "Torrent -> status string"), [NSString stringForSpeed: torrent.speedUpload]];
			break;
	case NITorrentStateChecking:
            string = [string stringByAppendingFormat: @" (%.2f%%)", 100*torrent.progress];
			break;
    default:
			break;
	}
	
    return string;
}


- (NSString *) torrentProgressString
{
    Torrent *torrent = [self representedObject];
    
    NSString * string = nil;
    
    if (torrent.size != torrent.downloadRate)
    {
		if (torrent.state == NITorrentStateChecking)
			string = [NSString stringWithFormat:@"%@", [NSString stringForFileSize: torrent.size]];
		else
		{
			string = [NSString stringWithFormat: NSLocalizedString(@"%@ of %@", "Torrent -> progress string"),
					  [NSString stringForFileSize: torrent.downloadRate], [NSString stringForFileSize: torrent.size]];
		
			CGFloat progress;
			
			progress = 100.0 * [torrent progress];
        
			string = [NSString localizedStringWithFormat: @"%@ (%.2f%%)", string, progress];
		}
    }
    else
    {
        NSString * downloadString;
		downloadString = [NSString stringForFileSize: [torrent size]];
        
        NSString * uploadString = [NSString stringWithFormat: NSLocalizedString(@"uploaded %@ (Ratio: %@)",
																				"Torrent -> progress string"), [NSString stringForFileSize: torrent.uploadRate],
								   [NSString stringForRatio:[torrent ratio]]];
        
        string = [downloadString stringByAppendingFormat: @", %@", uploadString];
    }
    
	//eta portion
	if (torrent.state == NITorrentStateLeeching)
	{
		if (torrent.speedDownload>0)
		{
			uint64_t eta = (torrent.size - torrent.downloadRate)/(torrent.speedDownload);
			string = [string stringByAppendingFormat: @" - %@", [NSString timeString: eta showSeconds: YES maxFields: 2]];
		}
		else
			string = [string stringByAppendingFormat: @" - %@", NSLocalizedString(@"remaining time unknown", "Torrent -> eta string")];
	}
    return string;
}
@end
