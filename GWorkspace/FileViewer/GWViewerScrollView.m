/* GWViewerScrollView.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2004
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

#include <AppKit/AppKit.h>
#include "FSNFunctions.h"
#include "GWViewerScrollView.h"
#include "GWViewer.h"
#include "GWSpatialViewer.h"

@implementation GWViewerScrollView

- (id)initWithFrame:(NSRect)frameRect
           inViewer:(id)aviewer
{
  self = [super initWithFrame: frameRect];

  if (self) {
    viewer = aviewer;
  }
  
  return self;
}

- (void)setDocumentView:(NSView *)aView
{
  [super setDocumentView: aView];
  
  if (aView != nil) {
    nodeView = [viewer nodeView];
    
    if ([nodeView needsDndProxy]) {
      [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                              NSFilenamesPboardType, 
                                              @"GWLSFolderPboardType", 
                                              @"GWRemoteFilenamesPboardType", 
                                              nil]];    
    } else {
      [self unregisterDraggedTypes];
    }
  } else {
    nodeView = nil;
    [self unregisterDraggedTypes];
  }
}

@end


@implementation GWViewerScrollView (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView draggingEntered: sender];
  }
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView draggingUpdated: sender];
  }
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    [nodeView draggingExited: sender];
  }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView prepareForDragOperation: sender];
  }
  return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    return [nodeView performDragOperation: sender];
  }
  return NO;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  if (nodeView && [nodeView needsDndProxy]) {
    [nodeView concludeDragOperation: sender];
  }
}

@end










