/* FileOpProgress.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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

#ifndef FILE_OPERATION_H
#define FILE_OPERATION_H

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>

@class NSTimer;
@class GWRemote;
@class NSImage;
@class ProgressView;

@interface FileOpProgress : NSObject 
{
  IBOutlet id win;
  IBOutlet id fromField;
  IBOutlet id toField;    
  IBOutlet id progressBox;
  ProgressView *pView;
  IBOutlet id pauseButt;
  IBOutlet id stopButt;

  NSString *serverName;
  NSString *title;
  int operationRef;
  BOOL paused;
  
  GWRemote *gwremote;
}

- (id)initWithOperationRef:(int)ref
             operationName:(NSString *)opname
                sourcePath:(NSString *)source
           destinationPath:(NSString *)destination
                serverName:(NSString *)sname
                windowRect:(NSRect)wrect;

- (void)activate;

- (void)done;

- (NSString *)serverName;

- (NSString *)title;

- (int)operationRef;

- (NSRect)windowRect;

- (IBAction)pauseOperation:(id)sender;

- (IBAction)stopOperation:(id)sender;

@end

@interface ProgressView : NSView 
{
  NSImage *image;
  float orx;
  NSTimer *progTimer;
}

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

@end

#endif // FILE_OPERATION_H
