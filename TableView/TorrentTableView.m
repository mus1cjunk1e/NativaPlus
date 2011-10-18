/******************************************************************************
 * $Id: TorrentTableView.m 9844 2010-01-01 21:12:04Z livings124 $
 *
 * Copyright (c) 2005-2010 Transmission authors and contributors
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

#import "TorrentTableView.h"
#import "Controller.h"
#import "Torrent.h"
#import "TorrentCell.h"
#import "TorrentGroup.h"
#import "DownloadsController.h"
#import "QuickLookController.h"
#import "GroupsController.h"
#import "PreferencesController.h"

#define MAX_GROUP 999999

@interface TorrentTableView (Private)

- (BOOL) pointInGroupStatusRect: (NSPoint) point;

- (void) setGroupStatusColumns;

@end

@implementation TorrentTableView

- (id) initWithCoder: (NSCoder *) decoder
{
    if ((self = [super initWithCoder: decoder]))
    {
        fDefaults = [NSUserDefaults standardUserDefaults];
        
        fTorrentCell = [[TorrentCell alloc] init];
        
        NSData * groupData = [fDefaults dataForKey: @"CollapsedGroups"];
        if (groupData)
            fCollapsedGroups = [[NSUnarchiver unarchiveObjectWithData: groupData] mutableCopy];
        else
            fCollapsedGroups = [[NSMutableIndexSet alloc] init];
        
        fMouseControlRow = -1;
        fMouseRevealRow = -1;
		fMouseGroupRow = -1;
        
        [self setDelegate: self];
        
        fPiecesBarPercent = [fDefaults boolForKey: @"PiecesBar"] ? 1.0f : 0.0f;
    }
    
    return self;
}

- (void) dealloc
{
    [fCollapsedGroups release];
    
    [fPiecesBarAnimation release];
    [fMenuTorrent release];
    
    [fSelectedValues release];
    
    [fTorrentCell release];
    
    [super dealloc];
}

- (void) awakeFromNib
{
    //set group columns to show ratio, needs to be in awakeFromNib to size columns correctly
    [self setGroupStatusColumns];
}

- (BOOL) isGroupCollapsed: (NSInteger) value
{
    if (value == -1)
        value = MAX_GROUP;
    
    return [fCollapsedGroups containsIndex: value];
}

- (void) removeCollapsedGroup: (NSInteger) value
{
    if (value == -1)
        value = MAX_GROUP;
    
    [fCollapsedGroups removeIndex: value];
}

- (void) removeAllCollapsedGroups
{
    [fCollapsedGroups removeAllIndexes];
}

- (void) saveCollapsedGroups
{
    [fDefaults setObject: [NSArchiver archivedDataWithRootObject: fCollapsedGroups] forKey: @"CollapsedGroups"];
}

- (BOOL) outlineView: (NSOutlineView *) outlineView isGroupItem: (id) item
{
    return ![item isKindOfClass: [Torrent class]];
}

- (CGFloat) outlineView: (NSOutlineView *) outlineView heightOfRowByItem: (id) item
{
    return [item isKindOfClass: [Torrent class]] ? [self rowHeight] : GROUP_SEPARATOR_HEIGHT;
}

- (NSCell *) outlineView: (NSOutlineView *) outlineView dataCellForTableColumn: (NSTableColumn *) tableColumn item: (id) item
{
    const BOOL group = ![item isKindOfClass: [Torrent class]];
    if (!tableColumn)
        return !group ? fTorrentCell : nil;
    else
        return group ? [tableColumn dataCellForRow: [self rowForItem: item]] : nil;
}

- (void) outlineView: (NSOutlineView *) outlineView willDisplayCell: (id) cell forTableColumn: (NSTableColumn *) tableColumn
    item: (id) item
{
    if ([item isKindOfClass: [Torrent class]])
    {
        [cell setRepresentedObject: item];
        
        const NSInteger row = [self rowForItem: item];
        [cell setControlHover: row == fMouseControlRow];
        [cell setRevealHover: row == fMouseRevealRow];
		[cell setGroupHover: row == fMouseGroupRow];
    }
    else
    {
        NSString * ident = [tableColumn identifier];
        if ([ident isEqualToString: @"UL Image"] || [ident isEqualToString: @"DL Image"])
        {
            //ensure arrows are white only when selected
            [[cell image] setTemplate: [cell backgroundStyle] == NSBackgroundStyleLowered];
        }
    }
}

- (NSRect) frameOfCellAtColumn: (NSInteger) column row: (NSInteger) row
{
    if (column == -1)
        return [self rectOfRow: row];
    else
    {
        NSRect rect = [super frameOfCellAtColumn: column row: row];
        
        //adjust placement for proper vertical alignment
        if (column == [self columnWithIdentifier: @"Group"])
            rect.size.height -= 1.0f;
        
        return rect;
    }
}

- (NSString *) outlineView: (NSOutlineView *) outlineView typeSelectStringForTableColumn: (NSTableColumn *) tableColumn item: (id) item
{
    return [item isKindOfClass: [Torrent class]] ? [item name]
            : [[self preparedCellAtColumn: [self columnWithIdentifier: @"Group"] row: [self rowForItem: item]] stringValue];
}

- (NSString *) outlineView: (NSOutlineView *) outlineView toolTipForCell: (NSCell *) cell rect: (NSRectPointer) rect
                tableColumn: (NSTableColumn *) column item: (id) item mouseLocation: (NSPoint) mouseLocation
{
    NSString * ident = [column identifier];
    if ([ident isEqualToString: @"DL"] || [ident isEqualToString: @"DL Image"])
        return NSLocalizedString(@"Download speed", "Torrent table -> group row -> tooltip");
    else if ([ident isEqualToString: @"UL"] || [ident isEqualToString: @"UL Image"])
        return [fDefaults boolForKey: @"DisplayGroupRowRatio"] ? NSLocalizedString(@"Ratio", "Torrent table -> group row -> tooltip")
                : NSLocalizedString(@"Upload speed", "Torrent table -> group row -> tooltip");
    else if (ident)
    {
        NSInteger count = [[item torrents] count];
        if (count == 1)
            return NSLocalizedString(@"1 transfer", "Torrent table -> group row -> tooltip");
        else
            return [NSString stringWithFormat: NSLocalizedString(@"%d transfers", "Torrent table -> group row -> tooltip"), count];
    }
    else
        return nil;
}


- (void) updateTrackingAreas
{
	[super updateTrackingAreas];
	
    [self removeButtonTrackingAreas];

    NSRange rows = [self rowsInRect: [self visibleRect]];
    if (rows.length == 0)
        return;
    
    NSPoint mouseLocation = [self convertPoint: [[self window] convertScreenToBase: [NSEvent mouseLocation]] fromView: nil];
    for (NSUInteger row = rows.location; row < NSMaxRange(rows); row++)
    {
        if (![[self itemAtRow: row] isKindOfClass: [Torrent class]])
            continue;
        
        NSDictionary * userInfo = [NSDictionary dictionaryWithObject: [NSNumber numberWithInteger: row] forKey: @"Row"];
        TorrentCell * cell = (TorrentCell *)[self preparedCellAtColumn: -1 row: row];
        [cell addTrackingAreasForView: self inRect: [self rectOfRow: row] withUserInfo: userInfo mouseLocation: mouseLocation];
    }
}

- (void) removeButtonTrackingAreas
{
    fMouseControlRow = -1;
    fMouseRevealRow = -1;
	fMouseGroupRow = -1;
    
    for (NSTrackingArea * area in [self trackingAreas])
    {
        if ([area owner] == self && [[area userInfo] objectForKey: @"Row"])
            [self removeTrackingArea: area];
    }
}

- (void) setGroupButtonHover: (NSInteger) row
{
    fMouseGroupRow = row;
    if (row >= 0)
        [self setNeedsDisplayInRect: [self rectOfRow: row]];
}

- (void) setControlButtonHover: (NSInteger) row
{
    fMouseControlRow = row;
    if (row >= 0)
        [self setNeedsDisplayInRect: [self rectOfRow: row]];
}

- (void) setRevealButtonHover: (NSInteger) row
{
    fMouseRevealRow = row;
    if (row >= 0)
        [self setNeedsDisplayInRect: [self rectOfRow: row]];
}

- (void) mouseEntered: (NSEvent *) event
{
    NSDictionary * dict = (NSDictionary *)[event userData];
    
    NSNumber * row;
    if ((row = [dict objectForKey: @"Row"]))
    {
        NSInteger rowVal = [row integerValue];
        NSString * type = [dict objectForKey: @"Type"];
        if ([type isEqualToString: @"Control"])
            fMouseControlRow = rowVal;
        else if ([type isEqualToString: @"Group"])
            fMouseGroupRow = rowVal;
        else
            fMouseRevealRow = rowVal;
        
        [self setNeedsDisplayInRect: [self rectOfRow: rowVal]];
    }
}

- (void) mouseExited: (NSEvent *) event
{
    NSDictionary * dict = (NSDictionary *)[event userData];
    
    NSNumber * row;
    if ((row = [dict objectForKey: @"Row"]))
    {
        NSString * type = [dict objectForKey: @"Type"];
        if ([type isEqualToString: @"Control"])
            fMouseControlRow = -1;
        else if ([type isEqualToString: @"Group"])
            fMouseGroupRow = -1;
        else
            fMouseRevealRow = -1;
        
        [self setNeedsDisplayInRect: [self rectOfRow: [row integerValue]]];
    }
}

- (void) outlineViewSelectionIsChanging: (NSNotification *) notification
{
    if (fSelectedValues)
        [self selectValues: fSelectedValues];
}

- (void) outlineViewItemDidExpand: (NSNotification *) notification
{
    NSInteger value = [[[notification userInfo] objectForKey: @"NSObject"] groupIndex];
    if (value < 0)
        value = MAX_GROUP;
    
    if ([fCollapsedGroups containsIndex: value])
    {
        [fCollapsedGroups removeIndex: value];
        [[NSNotificationCenter defaultCenter] postNotificationName: @"OutlineExpandCollapse" object: self];
    }
}

- (void) outlineViewItemDidCollapse: (NSNotification *) notification
{
    NSInteger value = [[[notification userInfo] objectForKey: @"NSObject"] groupIndex];
    if (value < 0)
        value = MAX_GROUP;
    
    [fCollapsedGroups addIndex: value];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"OutlineExpandCollapse" object: self];
}

- (void) mouseDown: (NSEvent *) event
{
	NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
    const NSInteger row = [self rowAtPoint: point];
    
    //check to toggle group status before anything else
    if ([self pointInGroupStatusRect: point])
    {
        [fDefaults setBool: ![fDefaults boolForKey: @"DisplayGroupRowRatio"] forKey: @"DisplayGroupRowRatio"];
        [self setGroupStatusColumns];
        
        return;
    }
    
    const BOOL pushed = row != -1 && (fMouseRevealRow == row || fMouseGroupRow == row ||fMouseControlRow == row);
    
    //if pushing a button, don't change the selected rows
    if (pushed)
        fSelectedValues = [[self selectedValues] retain];
    
    [super mouseDown: event];
    
    [fSelectedValues release];
    fSelectedValues = nil;
    
	if (row != -1 && fMouseGroupRow == row)
    {
        fGroupPushedRow = row;
        [self setNeedsDisplayInRect: [self rectOfRow: row]]; //ensure button is pushed down
        
        [self displayGroupMenuForEvent: event];
        
        fGroupPushedRow = -1;
        [self setNeedsDisplayInRect: [self rectOfRow: row]];
    }
    else if (!pushed && [event clickCount] == 2) //double click
    {
//        id item = nil;
//        if (row != -1)
//            item = [self itemAtRow: row];
//        
//        if (!item || [item isKindOfClass: [Torrent class]])
//            [fController showInfo: nil];
//        else
//        {
//            if ([self isItemExpanded: item])
//                [self collapseItem: item];
//            else
//                [self expandItem: item];
//        }
    }
    else;
}

- (void) selectValues: (NSArray *) values
{
    NSMutableIndexSet * indexSet = [NSMutableIndexSet indexSet];
    
    for (id item in values)
    {
        if ([item isKindOfClass: [Torrent class]])
        {
            const NSInteger index = [self rowForItem: item];
            if (index != -1)
                [indexSet addIndex: index];
        }
        else
        {
            const NSInteger group = [item groupIndex];
            for (NSInteger i = 0; i < [self numberOfRows]; i++)
            {
                id tableItem = [self itemAtRow: i];
                if ([tableItem isKindOfClass: [TorrentGroup class]] && group == [tableItem groupIndex])
                {
                    [indexSet addIndex: i];
                    break;
                }
            }
        }
    }
    
    [self selectRowIndexes: indexSet byExtendingSelection: NO];
}

- (NSArray *) selectedValues
{
    NSIndexSet * selectedIndexes = [self selectedRowIndexes];
    NSMutableArray * values = [NSMutableArray arrayWithCapacity: [selectedIndexes count]];
    
    for (NSUInteger i = [selectedIndexes firstIndex]; i != NSNotFound; i = [selectedIndexes indexGreaterThanIndex: i])
        [values addObject: [self itemAtRow: i]];
    
    return values;
}

- (NSArray *) selectedTorrents
{
    NSIndexSet * selectedIndexes = [self selectedRowIndexes];
    NSMutableArray * torrents = [NSMutableArray arrayWithCapacity: [selectedIndexes count]]; //take a shot at guessing capacity
    
    for (NSUInteger i = [selectedIndexes firstIndex]; i != NSNotFound; i = [selectedIndexes indexGreaterThanIndex: i])
    {
        id item = [self itemAtRow: i];
        if ([item isKindOfClass: [Torrent class]])
            [torrents addObject: item];
        else
        {
            NSArray * groupTorrents = [item torrents];
            [torrents addObjectsFromArray: groupTorrents];
            if ([self isItemExpanded: item])
                i +=[groupTorrents count];
        }
    }
    
    return torrents;
}

- (NSMenu *) menuForEvent: (NSEvent *) event
{
    NSInteger row = [self rowAtPoint: [self convertPoint: [event locationInWindow] fromView: nil]];
    if (row >= 0)
    {
        if (![self isRowSelected: row])
            [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        return [_controller contextRowMenu];
    }
    return nil;
}

//make sure that the pause buttons become orange when holding down the option key
- (void) flagsChanged: (NSEvent *) event
{
    [self display];
    [super flagsChanged: event];
}

//option-command-f will focus the filter bar's search field
- (void) keyDown: (NSEvent *) event
{
    const unichar firstChar = [[event charactersIgnoringModifiers] characterAtIndex: 0];
    
    if (firstChar == ' ')
	{
		//check location
		for (Torrent * torrent in [self selectedTorrents])
		{
			if ([[DownloadsController sharedDownloadsController] findLocation:torrent] != nil)
			{
				[QuickLookController show];
				break;
			}
		}
	}
	else
        [super keyDown: event];
}

- (NSRect) iconRectForRow: (NSInteger) row
{
    return [fTorrentCell iconRectForBounds: [self rectOfRow: row]];
}

- (BOOL) validateMenuItem: (NSMenuItem *) menuItem
{
    return YES;
}

- (void) toggleControlForTorrent: (Torrent *) torrent
{
    if ( !(torrent.state == NITorrentStateStopped || torrent.state == NITorrentStatePaused) )
        [[DownloadsController sharedDownloadsController] stop:torrent force:[[NSUserDefaults standardUserDefaults] boolForKey:NIForceStopKey] handler:nil];
    else
        [[DownloadsController sharedDownloadsController] start:torrent handler:nil];
}

- (void) displayGroupMenuForEvent: (NSEvent *) event
{
	const NSInteger row = [self rowAtPoint: [self convertPoint: [event locationInWindow] fromView: nil]];
    if (row < 0)
        return;
    
    //update file action menu
    fMenuTorrent = [[self itemAtRow: row] retain];
    
    //place menu below button
    NSRect rect = [fTorrentCell groupButtonRectForBounds: [self rectOfRow: row]];
    NSPoint location = rect.origin;
    location.y += rect.size.height;
    
	location = [self convertPoint: location toView: self];
    [_controller showGroupMenuForTorrent:fMenuTorrent atLocation:location];
    [fMenuTorrent release];
    fMenuTorrent = nil;
}


//alternating rows - first row after group row is white
- (void) highlightSelectionInClipRect: (NSRect) clipRect
{
    NSRect visibleRect = clipRect;
    NSRange rows = [self rowsInRect: visibleRect];
    BOOL start = YES;
    
    const CGFloat totalRowHeight = [self rowHeight] + [self intercellSpacing].height;
    
    NSRect gridRects[(NSInteger)(ceil(visibleRect.size.height / totalRowHeight / 2.0)) + 1]; //add one if partial rows at top and bottom
    NSInteger rectNum = 0;
    
    if (rows.length > 0)
    {
        //determine what the first row color should be
        if ([[self itemAtRow: rows.location] isKindOfClass: [Torrent class]])
        {
            for (NSInteger i = rows.location-1; i>=0; i--)
            {
                if (![[self itemAtRow: i] isKindOfClass: [Torrent class]])
                    break;
                start = !start;
            }
        }
        else
        {
            rows.location++;
            rows.length--;
        }
        
        NSInteger i;
        for (i = rows.location; i < NSMaxRange(rows); i++)
        {
            if (![[self itemAtRow: i] isKindOfClass: [Torrent class]])
            {
                start = YES;
                continue;
            }
            
            if (!start && ![self isRowSelected: i])
                gridRects[rectNum++] = [self rectOfRow: i];
            
            start = !start;
        }
        
        const CGFloat newY = NSMaxY([self rectOfRow: i-1]);
        visibleRect.size.height -= newY - visibleRect.origin.y;
        visibleRect.origin.y = newY;
    }
    
    const NSInteger numberBlankRows = ceil(visibleRect.size.height / totalRowHeight);
    
    //remaining visible rows continue alternating
    visibleRect.size.height = totalRowHeight;
    if (start)
        visibleRect.origin.y += totalRowHeight;
    
    for (NSInteger i = start ? 1 : 0; i < numberBlankRows; i += 2)
    {
        gridRects[rectNum++] = visibleRect;
        visibleRect.origin.y += 2.0 * totalRowHeight;
    }
    
    NSAssert([[NSColor controlAlternatingRowBackgroundColors] count] >= 2, @"There should be 2 alternating row colors");
    
    [[[NSColor controlAlternatingRowBackgroundColors] objectAtIndex: 1] set];
    NSRectFillList(gridRects, rectNum);
    
    [super highlightSelectionInClipRect: clipRect];
}


- (void) animationDidEnd: (NSAnimation *) animation
{
    if (animation == fPiecesBarAnimation)
    {
        [fPiecesBarAnimation release];
        fPiecesBarAnimation = nil;
    }
}

- (void) animation: (NSAnimation *) animation didReachProgressMark: (NSAnimationProgress) progress
{
    if (animation == fPiecesBarAnimation)
    {
        if ([fDefaults boolForKey: @"PiecesBar"])
            fPiecesBarPercent = progress;
        else
            fPiecesBarPercent = 1.0f - progress;
        
        [self reloadData];
    }
}

- (CGFloat) piecesBarPercent
{
    return fPiecesBarPercent;
}
@end

@implementation TorrentTableView (Private)

- (BOOL) pointInGroupStatusRect: (NSPoint) point
{
    NSInteger row = [self rowAtPoint: point];
    if (row < 0 || [[self itemAtRow: row] isKindOfClass: [Torrent class]])
        return NO;
    
    NSString * ident = [[[self tableColumns] objectAtIndex: [self columnAtPoint: point]] identifier];
    return [ident isEqualToString: @"UL"] || [ident isEqualToString: @"UL Image"]
            || [ident isEqualToString: @"DL"] || [ident isEqualToString: @"DL Image"];
}

- (void) setGroupStatusColumns
{
    const BOOL ratio = [fDefaults boolForKey: @"DisplayGroupRowRatio"];
    
    [[self tableColumnWithIdentifier: @"DL"] setHidden: ratio];
    [[self tableColumnWithIdentifier: @"DL Image"] setHidden: ratio];
}
@end
