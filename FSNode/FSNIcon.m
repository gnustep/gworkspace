/* FSNIcon.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "FSNIcon.h"
#include "FSNTextCell.h"
#include "FSNode.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

static id <DesktopApplication> desktopApp = nil;

static NSFont *labelFont = nil;

@implementation FSNIcon

- (void)dealloc
{
  RELEASE (node);
	TEST_RELEASE (hostname);
  TEST_RELEASE (selection);
  TEST_RELEASE (selectionTitle);
  RELEASE (icon);
  RELEASE (highlightPath);
  RELEASE (label);
  [super dealloc];
}

+ (void)initialize
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
  NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];

  if (appName && selName) {
    #ifdef GNUSTEP 
		Class desktopAppClass = [[NSBundle mainBundle] principalClass];
    #else
		Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
    #endif
    SEL sel = NSSelectorFromString(selName);

    desktopApp = [desktopAppClass performSelector: sel];
  }
  
  ASSIGN (labelFont, [NSFont systemFontOfSize: 12]);
}

- (id)initForNode:(FSNode *)anode
         iconSize:(int)isize
     iconPosition:(unsigned int)ipos
        gridIndex:(int)gindex
        dndSource:(BOOL)dndsrc
        acceptDnd:(BOOL)dndaccept
{
  self = [super init];

  if (self) {
    NSRect r = NSZeroRect;
    
    icnBounds = NSMakeRect(0, 0, isize, isize);
    
    ASSIGN (node, anode);
    selection = nil;
    selectionTitle = nil;
    
    ASSIGN (icon, [FSNodeRep iconOfSize: isize forNode: node]);
    
    dndSource = dndsrc;
    acceptDnd = dndaccept;
    
    selectable = YES;
    
    hlightRect = NSZeroRect;
    hlightRect.size.width = ceil(isize / 3 * 4);
    hlightRect.size.height = ceil(hlightRect.size.width * [FSNodeRep highlightHeightFactor]);
    if ((hlightRect.size.height - isize) < 4) {
      hlightRect.size.height = isize + 4;
    }
    ASSIGN (highlightPath, [FSNodeRep highlightPathOfSize: hlightRect.size]);
        
		if ([[node path] isEqual: path_separator()]) {
		  NSHost *host = [NSHost currentHost];
		  NSString *hname = [host name];
		  NSRange range = [hname rangeOfString: @"."];

		  if (range.length != 0) {	
			  hname = [hname substringToIndex: range.location];
		  } 			
      
		  ASSIGN (hostname, hname);
		} 
    
    label = [FSNTextCell new];
    [label setFont: [FSNIcon labelFont]];

    [self setNodeInfoShowType: FSNInfoNameType];
    
    labelRect = NSZeroRect;
    labelRect.size.width = ceil([label uncuttedTitleLenght] + [FSNodeRep labelMargin]);
    labelRect.size.height = floor([[label font] defaultLineHeightForFont]);

    icnPosition = ipos;
    gridIndex = gindex;
    
    if (icnPosition == NSImageLeft) {
      [label setAlignment: NSLeftTextAlignment];
      r.size.width = hlightRect.size.width + labelRect.size.width;
      r.size.height = hlightRect.size.height;
    
    } else if (icnPosition == NSImageAbove) {
      [label setAlignment: NSCenterTextAlignment];
      if (labelRect.size.width > hlightRect.size.width) {
        r.size.width = labelRect.size.width;
      } else {
        r.size.width = hlightRect.size.width;
      }
      r.size.height = labelRect.size.width + hlightRect.size.width;

    } else if (icnPosition == NSImageOnly) {
      if (selectable) {
        r.size.width = hlightRect.size.width;
        r.size.height = hlightRect.size.height;
      } else {
        r.size = icnBounds.size;
      }
      
    } else {
      r.size = icnBounds.size;
    }

    [self setFrame: r];

    if (acceptDnd) {
      NSArray *pbTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, 
                                                    @"GWRemoteFilenamesPboardType", 
                                                    nil];
      [self registerForDraggedTypes: pbTypes];    
    }

    isLocked = [node isLocked];

    container = nil;

    isSelected = NO; 
    
    dragdelay = 0;
    isDragTarget = NO;
    onSelf = NO;    
  }
  
  return self;
}

+ (NSFont *)labelFont
{
  return labelFont;
}

+ (void)setLabelFont:(NSFont *)afont
{
  ASSIGN (labelFont, afont);
}

- (void)setSelectable:(BOOL)value
{
  if (selectable != value) {
    selectable = value;
    [self tile];
  }
}

- (void)select
{
  if (isSelected) {
    return;
  }
  isSelected = YES;
  [container unselectOtherReps: self];	
  [container selectionDidChange];	
  [self setNeedsDisplay: YES]; 
}

- (void)unselect
{
  if (isSelected == NO) {
    return;
  }
	isSelected = NO;
  [container selectionDidChange];	
  [self setNeedsDisplay: YES];
}

- (BOOL)isSelected
{
  return isSelected;
}

- (void)tile
{
  NSRect frameRect = [self frame];
  NSSize sz = [icon size];
  int lblmargin = [FSNodeRep labelMargin];
  
  if (icnPosition == NSImageAbove) {
    labelRect.size.width = ceil([label uncuttedTitleLenght] + lblmargin);
  
    if (labelRect.size.width >= frameRect.size.width) {
      labelRect.size.width = frameRect.size.width;
      labelRect.origin.x = 0;
    } else {
      labelRect.origin.x = (frameRect.size.width - labelRect.size.width) / 2;
    }
  
    labelRect.origin.y = 0;
    labelRect.origin.y += ceil(lblmargin / 2);
    
    if (selectable) {
      float hlx = (frameRect.size.width - hlightRect.size.width) / 2;
      float hly = frameRect.size.height - hlightRect.size.height;
    
      if ((hlightRect.origin.x != hlx) || (hlightRect.origin.y != hly)) {
        NSAffineTransform *transform = [NSAffineTransform transform];
    
        [transform translateXBy: hlx - hlightRect.origin.x
                            yBy: hly - hlightRect.origin.y];
    
        [highlightPath transformUsingAffineTransform: transform];
      
        hlightRect.origin.x = hlx;
        hlightRect.origin.y = hly;      
      }
            
      icnBounds.origin.x = hlightRect.origin.x + ((hlightRect.size.width - sz.width) / 2);
      icnBounds.origin.y = hlightRect.origin.y + ((hlightRect.size.height - sz.height) / 2);
    
    } else {
      int baseShift = [FSNodeRep defaultIconBaseShift];
      icnBounds.origin.x = (frameRect.size.width - sz.width) / 2;
      icnBounds.origin.y = labelRect.size.height + baseShift;
    }

  } else if (icnPosition == NSImageLeft) {
    float icnspacew = selectable ? hlightRect.size.width : icnBounds.size.width;
  
    labelRect.size.width = ceil([label uncuttedTitleLenght] + lblmargin);
  
    if (labelRect.size.width >= (frameRect.size.width - icnspacew)) {
      labelRect.size.width = (frameRect.size.width - icnspacew);
    } 
  
    if (selectable) {
      if ((hlightRect.origin.x != 0) || (hlightRect.origin.y != 0)) {
        NSAffineTransform *transform = [NSAffineTransform transform];
    
        [transform translateXBy: 0 - hlightRect.origin.x
                            yBy: 0 - hlightRect.origin.y];
    
        [highlightPath transformUsingAffineTransform: transform];
      
        hlightRect.origin.x = 0;
        hlightRect.origin.y = 0;      
      }
            
      icnBounds.origin.x = (hlightRect.size.width - sz.width) / 2;
      icnBounds.origin.y = (hlightRect.size.height - sz.height) / 2;
            
      labelRect.origin.x = hlightRect.size.width;
      labelRect.origin.y = (hlightRect.size.height - labelRect.size.height) / 2;
  
    } else {
      icnBounds.origin.x = 0;
      icnBounds.origin.y = 0;
            
      labelRect.origin.x = icnBounds.size.width;
      labelRect.origin.y = (icnBounds.size.height - labelRect.size.height) / 2;
    }
    
  } else if (icnPosition == NSImageOnly) {
    if (selectable) {
      float hlx = (frameRect.size.width - hlightRect.size.width) / 2;
      float hly = (frameRect.size.height - hlightRect.size.height) / 2;
    
      if ((hlightRect.origin.x != hlx) || (hlightRect.origin.y != hly)) {
        NSAffineTransform *transform = [NSAffineTransform transform];
    
        [transform translateXBy: hlx - hlightRect.origin.x
                            yBy: hly - hlightRect.origin.y];
    
        [highlightPath transformUsingAffineTransform: transform];
      
        hlightRect.origin.x = hlx;
        hlightRect.origin.y = hly;      
      }
    }
    
    icnBounds.origin.x = (frameRect.size.width - sz.width) / 2;
    icnBounds.origin.y = (frameRect.size.height - sz.height) / 2;
  } 
   
  [self setNeedsDisplay: YES]; 
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  if (([theEvent type] == NSRightMouseDown) && isSelected) {
    return [container menuForEvent: theEvent];
  }
  return [super menuForEvent: theEvent]; 
}

- (void)viewDidMoveToSuperview
{
  [super viewDidMoveToSuperview];
  container = (NSView <FSNodeRepContainer> *)[self superview];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if ([node isLocked] == NO) {
	  if ([theEvent clickCount] > 1) {  
		  [container openSelectionInNewViewer: YES];
	  }  
  }  
}

- (void)mouseDown:(NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  BOOL onself = NO;
	NSEvent *nextEvent = nil;
  BOOL startdnd = NO;

  location = [self convertPoint: location fromView: nil];

  if (icnPosition == NSImageOnly) {
    onself = [self mouse: location inRect: icnBounds];
  } else {
    onself = ([self mouse: location inRect: icnBounds]
                        || [self mouse: location inRect: labelRect]);
  }

  if (onself) {
    if (selectable == NO) {
      return;
    }
    
	  if ([theEvent clickCount] == 1) {
		  if ([theEvent modifierFlags] & NSShiftKeyMask) {
			  [container setSelectionMask: FSNMultipleSelectionMask];    
         
			  if (isSelected) {
				  [self unselect];
				  return;
        } else {
				  [self select];
          //   [container unselectNameEditor];
			  }
        
		  } else {
			  [container setSelectionMask: NSSingleSelectionMask];
        
        if (isSelected == NO) {
				  [self select];
          //   [container unselectNameEditor];
			  }
		  }
    
      if (dndSource) {
        while (1) {
	        nextEvent = [[self window] nextEventMatchingMask:
    							                  NSLeftMouseUpMask | NSLeftMouseDraggedMask];

          if ([nextEvent type] == NSLeftMouseUp) {
            break;

          } else if ([nextEvent type] == NSLeftMouseDragged) {
	          if (dragdelay < 5) {
              dragdelay++;
            } else {     
              startdnd = YES;        
              break;
            }
          }
        }
      }
      
      if (startdnd == YES) {  
        [self startExternalDragOnEvent: nextEvent];    
      } 
	  } 
    
  } else {
    [container mouseDown: theEvent];
  }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
  return YES;
}

- (void)setFrame:(NSRect)frameRect
{
  [super setFrame: frameRect];
  [self tile];
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldBoundsSize
{
  [self tile];
}

- (void)drawRect:(NSRect)rect
{	 
  if (isSelected) {
    [[NSColor selectedControlColor] set];
//    [highlightPath stroke];
    [highlightPath fill];
    
    if (icnPosition != NSImageOnly) {
      NSFrameRect(labelRect);
      NSRectFill(labelRect);  
      [label drawWithFrame: labelRect inView: self];
    }
  } else {
    if (icnPosition != NSImageOnly) {
      [[container backgroundColor] set];
      NSFrameRect(labelRect);
      NSRectFill(labelRect);
      [label drawWithFrame: labelRect inView: self];
    }  
  }

	if (isLocked == NO) {	
    [icon compositeToPoint: icnBounds.origin operation: NSCompositeSourceOver];
	} else {						
    [icon dissolveToPoint: icnBounds.origin fraction: 0.3];
	}
}


//
// FSNodeRep protocol
//
- (void)setNode:(FSNode *)anode
{
  DESTROY (selection);
  DESTROY (selectionTitle);
  DESTROY (hostname);
  
  ASSIGN (node, anode);
  ASSIGN (icon, [FSNodeRep iconOfSize: icnBounds.size.width forNode: node]);

  if ([[node path] isEqual: path_separator()]) {
    NSHost *host = [NSHost currentHost];
    NSString *hname = [host name];
    NSRange range = [hname rangeOfString: @"."];

    if (range.length != 0) {	
      hname = [hname substringToIndex: range.location];
    } 			
      
    ASSIGN (hostname, hname);
  } 

  [self setNodeInfoShowType: showType];  
  [self setLocked: [node isLocked]];
  [self tile];
}

- (FSNode *)node
{
  return node;
}

- (void)showSelection:(NSArray *)selnodes
{
  int i;
    
  ASSIGN (node, [selnodes objectAtIndex: 0]);
  ASSIGN (selection, selnodes);
  ASSIGN (selectionTitle, ([NSString stringWithFormat: @"%i %@", 
                  [selection count], NSLocalizedString(@"elements", @"")]));
  ASSIGN (icon, [FSNodeRep multipleSelectionIconOfSize: icnBounds.size.width]);
  [label setStringValue: selectionTitle];

  [self setLocked: NO];
  for (i = 0; i < [selnodes count]; i++) {
    if ([FSNodeRep isNodeLocked: [selnodes objectAtIndex: i]]) {
      [self setLocked: YES];
      break;
    }
  }

  [self tile];
}

- (void)setFont:(NSFont *)fontObj
{
  [label setFont: fontObj];
  labelRect.size.width = ceil([label uncuttedTitleLenght] + [FSNodeRep labelMargin]);
  labelRect.size.height = floor([[label font] defaultLineHeightForFont]);
  [self tile];
}

- (void)setIconSize:(int)isize
{
  icnBounds = NSMakeRect(0, 0, isize, isize);
  ASSIGN (icon, [FSNodeRep iconOfSize: isize forNode: node]);
  hlightRect.size.width = ceil(isize / 3 * 4);
  hlightRect.size.height = ceil(hlightRect.size.width * [FSNodeRep highlightHeightFactor]);
  if ((hlightRect.size.height - isize) < 4) {
    hlightRect.size.height = isize + 4;
  }
  hlightRect.origin.x = 0;
  hlightRect.origin.y = 0;
  ASSIGN (highlightPath, [FSNodeRep highlightPathOfSize: hlightRect.size]); 
  [self tile];
}

- (void)setIconPosition:(unsigned int)ipos
{
  icnPosition = ipos;

  if (icnPosition == NSImageLeft) {
    [label setAlignment: NSLeftTextAlignment];
  } else if (icnPosition == NSImageAbove) {
    [label setAlignment: NSCenterTextAlignment];
  } 
  
  [self tile];
}

- (void)setNodeInfoShowType:(FSNInfoType)type
{
  showType = type;

  if (selection) {
    [label setStringValue: selectionTitle];
    return;
  }
  
  switch(showType) {
    case FSNInfoNameType:
      [label setStringValue: (hostname ? hostname : [node name])];
      break;
    case FSNInfoKindType:
      [label setStringValue: [node typeDescription]];
      break;
    case FSNInfoDateType:
      [label setStringValue: [node modDateDescription]];
      break;
    case FSNInfoSizeType:
      [label setStringValue: [node sizeDescription]];
      break;
    case FSNInfoOwnerType:
      [label setStringValue: [node owner]];
      break;
    default:
      [label setStringValue: [node name]];
      break;
  }
}

- (void)setLocked:(BOOL)value
{
	if (isLocked == value) {
		return;
	}
	isLocked = value;
	[label setTextColor: (isLocked ? [NSColor disabledControlTextColor] 
																							: [NSColor controlTextColor])];
	[self setNeedsDisplay: YES];		
}

- (void)checkLocked
{
  [self setLocked: [node isLocked]];
}

- (BOOL)isLocked
{
	return isLocked;
}

- (void)setGridIndex:(int)index
{
  gridIndex = index;
}

- (int)gridIndex
{
  return gridIndex;
}

- (int)compareAccordingToName:(FSNIcon *)aIcon
{
  return [node compareAccordingToName: [aIcon node]];
}

- (int)compareAccordingToKind:(FSNIcon *)aIcon
{
  return [node compareAccordingToKind: [aIcon node]];
}

- (int)compareAccordingToDate:(FSNIcon *)aIcon
{
  return [node compareAccordingToDate: [aIcon node]];
}

- (int)compareAccordingToSize:(FSNIcon *)aIcon
{
  return [node compareAccordingToSize: [aIcon node]];
}

- (int)compareAccordingToOwner:(FSNIcon *)aIcon
{
  return [node compareAccordingToOwner: [aIcon node]];
}

- (int)compareAccordingToGroup:(FSNIcon *)aIcon
{
  return [node compareAccordingToGroup: [aIcon node]];
}

- (int)compareAccordingToIndex:(FSNIcon *)aIcon
{
  return (gridIndex >= [aIcon gridIndex]) ? NSOrderedAscending : NSOrderedDescending;
}

@end


@implementation FSNIcon (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSArray *selectedPaths = [container selectedPaths];

  [pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] 
             owner: nil];
  
  if ([pb setPropertyList: selectedPaths forType: NSFilenamesPboardType]) {
    NSImage *dragIcon;
    NSPoint dragPoint;
                  
    if ([selectedPaths count] == 1) {
      dragIcon = icon;
    } else {
      dragIcon = [FSNodeRep multipleSelectionIconOfSize: icnBounds.size.width];
    }     
                  
    dragPoint = [event locationInWindow];      
    dragPoint = [self convertPoint: dragPoint fromView: nil];

    [self dragImage: dragIcon
                 at: dragPoint 
             offset: NSZeroSize
              event: event
         pasteboard: pb
             source: self
          slideBack: YES];
  }
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationAll;
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
	dragdelay = 0;
  onSelf = NO;
  [container restoreLastSelection];
}

@end


@implementation FSNIcon (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
	NSString *fromPath;
  NSString *nodePath;
  NSString *prePath;
	int count;

  isDragTarget = NO;
  onSelf = NO;
	
  if (selection || isLocked || ([node isDirectory] == NO) 
                    || [node isPackage] || ([node isWritable] == NO)) {
    return NSDragOperationNone;
  }
  	
	pb = [sender draggingPasteboard];

  if ([[pb types] containsObject: NSFilenamesPboardType]) {
    sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
       
  } else if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 
    NSDictionary *pbDict = [NSUnarchiver unarchiveObjectWithData: pbData];
    
    sourcePaths = [pbDict objectForKey: @"paths"];
  } else {
    return NSDragOperationNone;
  }
  
	count = [sourcePaths count];
	if (count == 0) {
		return NSDragOperationNone;
  } 
  
  nodePath = [node path];
  
  if (selection) {
    if ([selection isEqual: sourcePaths]) {
      onSelf = YES;
    }  
  } else if (count == 1) {
    if ([nodePath isEqual: [sourcePaths objectAtIndex: 0]]) {
      onSelf = YES;
    }  
  }

  if (onSelf) {
    isDragTarget = YES;
    return NSDragOperationAll;  
  }

	fromPath = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];

	if ([nodePath isEqual: fromPath]) {
		return NSDragOperationNone;
  }  

  if ([sourcePaths containsObject: nodePath]) {
    return NSDragOperationNone;
  }

  prePath = [NSString stringWithString: nodePath];

  while (1) {
    if ([sourcePaths containsObject: prePath]) {
      return NSDragOperationNone;
    }
    if ([prePath isEqual: path_separator()]) {
      break;
    }            
    prePath = [prePath stringByDeletingLastPathComponent];
  }

  ASSIGN (icon, [FSNodeRep openFolderIconOfSize: icnBounds.size.width 
                                        forNode: node]);
  [self setNeedsDisplay: YES];   

  isDragTarget = YES;

	sourceDragMask = [sender draggingSourceOperationMask];

	if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}
    
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

  if (isDragTarget == NO) {
    return NSDragOperationNone;
  } else if (sourceDragMask == NSDragOperationCopy) {
		return NSDragOperationCopy;
	} else if (sourceDragMask == NSDragOperationLink) {
		return NSDragOperationLink;
	} else {
		return NSDragOperationAll;
	}

	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (isDragTarget == YES) {
    isDragTarget = NO;  
    if (onSelf == NO) { 
      ASSIGN (icon, [FSNodeRep iconOfSize: icnBounds.size.width forNode: node]);
      [container setNeedsDisplayInRect: [self frame]];   
      [self setNeedsDisplay: YES];   
    }
		onSelf = NO;
  }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return isLocked ? NO : isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return isLocked ? NO : isDragTarget;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb;
  NSDragOperation sourceDragMask;
	NSArray *sourcePaths;
  NSString *operation, *source;
  NSMutableArray *files;
	NSMutableDictionary *opDict;
	NSString *trashPath;
  int i;

	isDragTarget = NO;  

  if (isLocked) {
    return;
  }

  if (onSelf) {
		[container resizeWithOldSuperviewSize: [container frame].size]; 
    onSelf = NO;		
    return;
  }	

  ASSIGN (icon, [FSNodeRep iconOfSize: icnBounds.size.width forNode: node]);
  [self setNeedsDisplay: YES];

	sourceDragMask = [sender draggingSourceOperationMask];
  pb = [sender draggingPasteboard];
    
  if ([[pb types] containsObject: @"GWRemoteFilenamesPboardType"]) {  
    NSData *pbData = [pb dataForType: @"GWRemoteFilenamesPboardType"]; 

    [desktopApp concludeRemoteFilesDragOperation: pbData
                                     atLocalPath: [node path]];
    return;
  }
    
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];

  source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  
  trashPath = [desktopApp trashPath];

  if ([source isEqual: trashPath]) {
  		operation = @"GWorkspaceRecycleOutOperation";
	} else {	
		if (sourceDragMask == NSDragOperationCopy) {
			operation = NSWorkspaceCopyOperation;
		} else if (sourceDragMask == NSDragOperationLink) {
			operation = NSWorkspaceLinkOperation;
		} else {
			operation = NSWorkspaceMoveOperation;
		}
  }
  
  files = [NSMutableArray arrayWithCapacity: 1];    
  for(i = 0; i < [sourcePaths count]; i++) {    
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];
  }  

	opDict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[opDict setObject: operation forKey: @"operation"];
	[opDict setObject: source forKey: @"source"];
	[opDict setObject: [node path] forKey: @"destination"];
	[opDict setObject: files forKey: @"files"];

  [desktopApp performFileOperation: opDict];
}

@end


