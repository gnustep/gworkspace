/* Shelf.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWorkspace application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#ifndef SHELF_H
#define SHELF_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "IconViewsProtocol.h"
  #else
#include <GWorkspace/IconViewsProtocol.h>
  #endif

#define MAXSHELFHEIGHT  300

#ifndef max
#define max(a,b) ((a) > (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a):(b))
#endif

typedef struct {
  float x;  
  float y;  
	int index;
	int used; 
} gridpoint;

typedef gridpoint *(*GridPointIMP)(id, SEL, NSPoint);

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSNotification;
@class NSImage;
@class IconViewsIcon;
@class NSFileManager;
@class GWorkspace;

@interface Shelf : NSView <IconViewsProtocol>
{
	NSMutableArray *icons; 
  NSString *viewerPath;
	NSMutableArray *watchedPaths;
  int cellsWidth;
	gridpoint *gpoints;
	int pcount;
	BOOL isDragTarget;
	NSImage *dragImage;
	NSPoint dragPoint;
	NSRect dragRect;	
	SEL makePosSel;
	IMP makePos;
	SEL gridPointSel;
	GridPointIMP gridPoint;
  BOOL isShiftClick;
  id delegate;
  NSFileManager *fm;
  GWorkspace *gw;
}

- (id)initWithIconsDicts:(NSArray *)iconsDicts rootPath:(NSString *)rpath;

- (NSArray *)iconsDicts;

- (void)addIconWithPaths:(NSArray *)iconpaths withGridIndex:(int)index;

- (void)sortIcons;

- (NSArray *)icons;

- (void)updateIcons;

- (void)cellsWidthChanged:(NSNotification *)notification;

- (void)fileSystemWillChange:(NSNotification *)notification;

- (void)fileSystemDidChange:(NSNotification *)notification;

- (void)watcherNotification:(NSNotification *)notification;

- (void)setWatchers;

- (void)setWatcherForPath:(NSString *)path;

- (void)unsetWatchers;

- (void)unsetWatcherForPath:(NSString *)path;

- (void)makePositions;

- (gridpoint *)gridPointNearestToPoint:(NSPoint)p;

- (BOOL)isFreePosition:(NSPoint)pos;

@end

@interface Shelf(DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender;

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender;

- (void)draggingExited:(id <NSDraggingInfo>)sender;

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;

@end

@interface NSObject(ShelfDelegateMethods)

- (NSArray *)getSelectedPaths;

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths;

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
              animateImage:(NSImage *)image startingAtPoint:(NSPoint)startp;

- (void)shelf:(Shelf *)sender openCurrentSelection:(NSArray *)paths 
                                         newViewer:(BOOL)newv;
                                         
- (void)shelf:(Shelf *)sender keyDown:(NSEvent *)theEvent;                                         

- (void)shelf:(Shelf *)sender mouseDown:(NSEvent *)theEvent;                                         

@end

@interface FinderShelf : Shelf

@end

#endif // SHELF_H
