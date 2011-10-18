/******************************************************************************
 * $Id: DragOverlayWindow.m 9844 2010-01-01 21:12:04Z livings124 $
 *
 * Copyright (c) 2007-2010 Transmission authors and contributors
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

#import "DragOverlayWindow.h"
#import "DragOverlayView.h"
#import "NSStringTorrentAdditions.h"

@implementation DragOverlayWindow

- (id) initWithWindow: (NSWindow *) window
{
    if ((self = ([super initWithContentRect: NSMakeRect(0, 0, 1.0, 1.0) styleMask: NSBorderlessWindowMask
                    backing: NSBackingStoreBuffered defer: NO])))
    {
        [self setBackgroundColor: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.5]];
        [self setAlphaValue: 0.0];
        [self setOpaque: NO];
        [self setHasShadow: NO];
        
        DragOverlayView * view = [[DragOverlayView alloc] initWithFrame: [self frame]];
        [self setContentView: view];
        [view release];
        
        [self setReleasedWhenClosed: NO];
        [self setIgnoresMouseEvents: YES];
        
        fFadeInAnimation = [[NSViewAnimation alloc] initWithViewAnimations: [NSArray arrayWithObject:
                                [NSDictionary dictionaryWithObjectsAndKeys: self, NSViewAnimationTargetKey,
                                NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil]]];
        [fFadeInAnimation setDuration: 0.15];
        [fFadeInAnimation setAnimationBlockingMode: NSAnimationNonblockingThreaded];
        
        fFadeOutAnimation = [[NSViewAnimation alloc] initWithViewAnimations: [NSArray arrayWithObject:
                                [NSDictionary dictionaryWithObjectsAndKeys: self, NSViewAnimationTargetKey,
                                NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil]]];
        [fFadeOutAnimation setDuration: 0.5];
        [fFadeOutAnimation setAnimationBlockingMode: NSAnimationNonblockingThreaded];
        
        [window addChildWindow: self ordered: NSWindowAbove];
    }
    return self;
}

- (void) dealloc
{
    [fFadeInAnimation release];
    [fFadeOutAnimation release];
    
    [super dealloc];
}

- (void) setFile: (NSString *) file
{
    [[self contentView] setOverlay: [NSImage imageNamed: @"CreateLarge.png"]
        mainLine: NSLocalizedString(@"Create a Torrent File", "Drag overlay -> file") subLine: file];
    [self fadeIn];
}

- (void) setURL: (NSString *) url
{
    [[self contentView] setOverlay: [NSImage imageNamed: @"Globe.png"]
        mainLine: NSLocalizedString(@"Web Address", "Drag overlay -> url") subLine: url];
    [self fadeIn];
}

- (void) setImageAndMessage:(NSImage*) image mainMessage:(NSString *) mainMessage message:(NSString *) message
{
    [[self contentView] setOverlay: image
						  mainLine:mainMessage subLine: message];
    [self fadeIn];
}


- (void) fadeIn
{
    //stop other animation and set to same progress
    if ([fFadeOutAnimation isAnimating])
    {
        [fFadeOutAnimation stopAnimation];
        [fFadeInAnimation setCurrentProgress: 1.0 - [fFadeOutAnimation currentProgress]];
    }
    [self setFrame: [[self parentWindow] frame] display: YES];
    [fFadeInAnimation startAnimation];
}

- (void) fadeOut
{
    //stop other animation and set to same progress
    if ([fFadeInAnimation isAnimating])
    {
        [fFadeInAnimation stopAnimation];
        [fFadeOutAnimation setCurrentProgress: 1.0 - [fFadeInAnimation currentProgress]];
    }
    if ([self alphaValue] > 0.0)
        [fFadeOutAnimation startAnimation];
}

@end
