/* MDIndexing.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2006
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include "MDIndexing.h"
#include "StartAppWin.h"

BOOL subPathOfPath(NSString *p1, NSString *p2);

BOOL isDotFile(NSString *path);


@implementation MDIndexing

- (void)dealloc
{
  TEST_RELEASE (indexedPaths);
  TEST_RELEASE (excludedPaths);
  TEST_RELEASE (startAppWin);  
  TEST_RELEASE (extractorsInfoPath);
  TEST_RELEASE (extractorsInfoLock);
    
	[super dealloc];
}

- (void)mainViewDidLoad
{
  if (loaded == NO) {
    id cell;
    float fonth;
    int i;
    
    fm = [NSFileManager defaultManager];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
    indexedPaths = [NSMutableArray new];
    excludedPaths = [NSMutableArray new];

    [self readDefaults];

    [indexedScroll setBorderType: NSBezelBorder];
    [indexedScroll setHasHorizontalScroller: YES];
    [indexedScroll setHasVerticalScroller: YES]; 

    cell = [NSBrowserCell new];
    fonth = [[cell font] defaultLineHeightForFont];

    indexedMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	              mode: NSRadioModeMatrix 
                               prototype: cell
			       							  numberOfRows: 0 
                         numberOfColumns: 0];
    RELEASE (cell);                     
    [indexedMatrix setIntercellSpacing: NSZeroSize];
    [indexedMatrix setCellSize: NSMakeSize([indexedScroll contentSize].width, fonth)];
    [indexedMatrix setAutoscroll: YES];
	  [indexedMatrix setAllowsEmptySelection: YES];
	  [indexedScroll setDocumentView: indexedMatrix];	
    RELEASE (indexedMatrix);

    for (i = 0; i < [indexedPaths count]; i++) {
      NSString *name = [indexedPaths objectAtIndex: i];
      int count = [[indexedMatrix cells] count];

      [indexedMatrix insertRow: count];
      cell = [indexedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: name];
      [cell setLeaf: YES];  
    }
    
    [self adjustMatrix: indexedMatrix];
    [indexedMatrix sizeToCells]; 
    [indexedMatrix setTarget: self]; 
    [indexedMatrix setAction: @selector(indexedMatrixAction:)]; 

    [indexedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];

    [excludedScroll setBorderType: NSBezelBorder];
    [excludedScroll setHasHorizontalScroller: YES];
    [excludedScroll setHasVerticalScroller: YES]; 

    excludedMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	              mode: NSRadioModeMatrix 
                               prototype: [[NSBrowserCell new] autorelease]
			       							  numberOfRows: 0 
                         numberOfColumns: 0];
    [excludedMatrix setIntercellSpacing: NSZeroSize];
    [excludedMatrix setCellSize: NSMakeSize([excludedScroll contentSize].width, fonth)];
    [excludedMatrix setAutoscroll: YES];
	  [excludedMatrix setAllowsEmptySelection: YES];
	  [excludedScroll setDocumentView: excludedMatrix];	
    RELEASE (excludedMatrix);

    for (i = 0; i < [excludedPaths count]; i++) {
      NSString *path = [excludedPaths objectAtIndex: i];
      int count = [[excludedMatrix cells] count];

      [excludedMatrix insertRow: count];
      cell = [excludedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
    }

    [self adjustMatrix: excludedMatrix];    
    [excludedMatrix sizeToCells]; 
    [excludedMatrix setTarget: self]; 
    [excludedMatrix setAction: @selector(excludedMatrixAction:)]; 

    [excludedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];

    unselectReply = NSUnselectNow;
    loaded = YES;
  
    [revertButton setEnabled: NO];
    [applyButton setEnabled: NO];
        
    startAppWin = [[StartAppWin alloc] init];
    
    extractorsInfoPath = nil;
    [self setupDbPaths];
  }
}

- (void)indexedMatrixAction:(id)sender
{
  [indexedRemove setEnabled: ([[indexedMatrix cells] count] > 0)];  
}

- (IBAction)indexedButtAction:(id)sender
{
  NSPreferencePaneUnselectReply oldReply = unselectReply;
  NSArray *cells = [indexedMatrix cells];
  int count = [cells count];
  id cell;
  unsigned i;

#define IND_ERR_RETURN(x) \
do { \
NSRunAlertPanel(nil, \
NSLocalizedString(x, @""), \
NSLocalizedString(@"Ok", @""), \
nil, \
nil); \
unselectReply = oldReply; \
return; \
} while (0)

  if (sender == indexedAdd) {
    NSString *path;
    
    unselectReply = NSUnselectCancel; 
    path = [self chooseNewPath];
    
    if (path) {
      if (isDotFile(path)) {
        IND_ERR_RETURN (@"Paths containing \'.\' are not indexable!");
      }

      if ([indexedPaths containsObject: path]) {
        IND_ERR_RETURN (@"The path is already present!");
      }
      
      for (i = 0; i < [indexedPaths count]; i++) {
        if (subPathOfPath([indexedPaths objectAtIndex: i], path)) {
          IND_ERR_RETURN (@"This path is a subpath of an already indexable path!");
        }
      }
    
      for (i = 0; i < [excludedPaths count]; i++) {
        NSString *exclpath = [excludedPaths objectAtIndex: i];
        
        if ([path isEqual: exclpath] || subPathOfPath(exclpath, path)) {
          IND_ERR_RETURN (@"This path is excluded from the indexable paths!");
        }
      }
    
      [indexedPaths addObject: path];
      
      [indexedMatrix insertRow: count];
      cell = [indexedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
      [self adjustMatrix: indexedMatrix];
      [indexedMatrix sizeToCells]; 
      [indexedMatrix selectCellAtRow: count column: 0]; 
      
      [indexedMatrix sendAction];  
          
    } else {
      unselectReply = oldReply;
    }

  } else if (sender == indexedRemove) {
    cell = [indexedMatrix selectedCell];  
    
    if (cell) {  
      int row, col;
      
      [indexedPaths removeObject: [cell stringValue]];

      [indexedMatrix getRow: &row column: &col ofCell: cell];
      [indexedMatrix removeRow: row];
      [self adjustMatrix: indexedMatrix];
      [indexedMatrix sizeToCells]; 
      
      [indexedMatrix sendAction];
      
      unselectReply = NSUnselectCancel; 
    
    } else {
      unselectReply = oldReply;
    }
  }
  
  [revertButton setEnabled: (unselectReply != NSUnselectNow)];   
  [applyButton setEnabled: (unselectReply != NSUnselectNow)];  
}

- (void)excludedMatrixAction:(id)sender
{
  [excludedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];  
}

- (IBAction)excludedButtAction:(id)sender
{
  NSPreferencePaneUnselectReply oldReply = unselectReply;
  NSArray *cells = [excludedMatrix cells];
  int count = [cells count];
  id cell;
  unsigned i;

#define EXCL_ERR_RETURN(x) \
do { \
NSRunAlertPanel(nil, \
NSLocalizedString(x, @""), \
NSLocalizedString(@"Ok", @""), \
nil, \
nil); \
unselectReply = oldReply; \
return; \
} while (0)

  if (sender == excludedAdd) {
    NSString *path;
    
    unselectReply = NSUnselectCancel; 
    path = [self chooseNewPath];
    
    if (path) {
      BOOL valid = NO;

      if (isDotFile(path)) {
        IND_ERR_RETURN (@"Paths containing \'.\' are not indexable by default!");
      }
    
      for (i = 0; i < [indexedPaths count]; i++) {
        if (subPathOfPath([indexedPaths objectAtIndex: i], path)) {
          valid = YES;
          break;  
        }
      }
    
      if (valid == NO) {
        EXCL_ERR_RETURN (@"An excluded path must be a subpath of an indexable path!");
      }
    
      if ([excludedPaths containsObject: path]) {
        EXCL_ERR_RETURN (@"The path is already present!");
      }
      
      for (i = 0; i < [excludedPaths count]; i++) {
        if (subPathOfPath([excludedPaths objectAtIndex: i], path)) {
          EXCL_ERR_RETURN (@"This path is a subpath of an already excluded path!");
        }
      }
    
      for (i = 0; i < [indexedPaths count]; i++) {
        NSString *idxpath = [indexedPaths objectAtIndex: i];
        
        if ([path isEqual: idxpath] || subPathOfPath(path, idxpath)) {
          EXCL_ERR_RETURN (@"This path would exclude a path defined indexable!");
        }
      }
    
      [excludedPaths addObject: path];
      
      [excludedMatrix insertRow: count];
      cell = [excludedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
      [self adjustMatrix: excludedMatrix];
      [excludedMatrix sizeToCells]; 
      [excludedMatrix selectCellAtRow: count column: 0]; 
      
      [excludedMatrix sendAction];  
          
    } else {
      unselectReply = oldReply;
    }

  } else if (sender == excludedRemove) {
    cell = [excludedMatrix selectedCell];  
    
    if (cell) {  
      int row, col;
      
      [excludedPaths removeObject: [cell stringValue]];

      [excludedMatrix getRow: &row column: &col ofCell: cell];
      [excludedMatrix removeRow: row];
      [self adjustMatrix: excludedMatrix];
      [excludedMatrix sizeToCells]; 
      
      [excludedMatrix sendAction];
      
      unselectReply = NSUnselectCancel; 
    
    } else {
      unselectReply = oldReply;
    }
  }
  
  [revertButton setEnabled: (unselectReply != NSUnselectNow)];   
  [applyButton setEnabled: (unselectReply != NSUnselectNow)];    
}

- (IBAction)enableSwitchAction:(id)sender
{
  BOOL oldEnabled = indexingEnabled;

  indexingEnabled = ([enableSwitch state] == NSOnState);

  [revertButton setEnabled: (oldEnabled != indexingEnabled)];   
  [applyButton setEnabled: (oldEnabled != indexingEnabled)];    
}

- (IBAction)revertButtAction:(id)sender
{
  id cell;
  unsigned i;

  [indexedPaths removeAllObjects];
  [excludedPaths removeAllObjects];
  
  [self readDefaults];  
  
  if ([indexedMatrix numberOfColumns] > 0) { 
    [indexedMatrix removeColumn: 0];
  }
  
  for (i = 0; i < [indexedPaths count]; i++) {
    NSString *name = [indexedPaths objectAtIndex: i];
    int count = [[indexedMatrix cells] count];

    [indexedMatrix insertRow: count];
    cell = [indexedMatrix cellAtRow: count column: 0];   
    [cell setStringValue: name];
    [cell setLeaf: YES];  
  }

  [self adjustMatrix: indexedMatrix];
  [indexedMatrix sizeToCells]; 

  [indexedRemove setEnabled: ([[indexedMatrix cells] count] > 0)];
  
  if ([excludedMatrix numberOfColumns] > 0) {
    [excludedMatrix removeColumn: 0];
  }
  
  for (i = 0; i < [excludedPaths count]; i++) {
    NSString *path = [excludedPaths objectAtIndex: i];
    int count = [[excludedMatrix cells] count];

    [excludedMatrix insertRow: count];
    cell = [excludedMatrix cellAtRow: count column: 0];   
    [cell setStringValue: path];
    [cell setLeaf: YES];  
  }

  [self adjustMatrix: excludedMatrix];    
  [excludedMatrix sizeToCells]; 

  [excludedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];

  unselectReply = NSUnselectNow;
  [revertButton setEnabled: NO];   
  [applyButton setEnabled: NO];
}

- (IBAction)applyButtAction:(id)sender
{
  [self applyChanges];  
  unselectReply = NSUnselectNow; 
  [revertButton setEnabled: NO];   
  [applyButton setEnabled: NO];
}

- (void)adjustMatrix:(NSMatrix *)matrix
{
  NSArray *cells = [matrix cells];
  
  if (cells && [cells count]) {
    NSSize cellsize = [matrix cellSize];
    float margin = 10.0;
    float maxw = margin;
    NSDictionary *fontAttr;
    unsigned i;

    fontAttr = [NSDictionary dictionaryWithObject: [[cells objectAtIndex: 0] font] 
                                           forKey: NSFontAttributeName];
                                           
    for (i = 0; i < [cells count]; i++) {
      NSString *str = [[cells objectAtIndex: i] stringValue];
      float strw = [str sizeWithAttributes: fontAttr].width + margin;
  
      maxw = (strw > maxw) ? strw : maxw;
    }
    
    if (maxw > cellsize.width) {
      [matrix setCellSize: NSMakeSize(maxw, cellsize.height)];
    }
  }
}

- (void)setupDbPaths
{
  NSString *dbdir;
  NSString *lockpath;
  BOOL isdir;
  
  dbdir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  dbdir = [dbdir stringByAppendingPathComponent: @"gmds"];

  if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
    if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"unable to create the db directory.", @""), 
                      NSLocalizedString(@"Ok", @""), 
                      nil, 
                      nil); 
      return;
    }
  }

  dbdir = [dbdir stringByAppendingPathComponent: @".db"];

  if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
    if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"unable to create the db directory.", @""), 
                      NSLocalizedString(@"Ok", @""), 
                      nil, 
                      nil); 
      return;
    }
  }

  ASSIGN (extractorsInfoPath, [dbdir stringByAppendingPathComponent: @"extractors.plist"]);

  lockpath = [dbdir stringByAppendingPathComponent: @"extractors.lock"];
  extractorsInfoLock = [[NSDistributedLock alloc] initWithPath: lockpath];
}

- (NSDictionary *)extractorsInfo
{
  if (extractorsInfoPath && [fm isReadableFileAtPath: extractorsInfoPath]) {
    NSDictionary *info;

    if ([extractorsInfoLock tryLock] == NO) {
      unsigned sleeps = 0;

      if ([[extractorsInfoLock lockDate] timeIntervalSinceNow] < -20.0) {
	      NS_DURING
	        {
	      [extractorsInfoLock breakLock];
	        }
	      NS_HANDLER
	        {
        NSLog(@"Unable to break lock %@ ... %@", extractorsInfoLock, localException);
	        }
	      NS_ENDHANDLER
      }

      for (sleeps = 0; sleeps < 10; sleeps++) {
	      if ([extractorsInfoLock tryLock]) {
	        break;
	      }

        sleeps++;
	      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	    }

      if (sleeps >= 10) {
        NSLog(@"Unable to obtain lock %@", extractorsInfoLock);
        return nil;
	    }
    }

    info = [NSDictionary dictionaryWithContentsOfFile: extractorsInfoPath];
    [extractorsInfoLock unlock];

    return info;
  }
  
  return nil;
}










- (NSString *)chooseNewPath
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	int result;

	[openPanel setTitle: NSLocalizedString(@"Choose directory", @"")];	
  [openPanel setAllowsMultipleSelection: NO];
  [openPanel setCanChooseFiles: NO];
  [openPanel setCanChooseDirectories: YES];

  result = [openPanel runModalForDirectory: nil file: nil types: nil];

  return ((result == NSOKButton) ? [openPanel filename] : nil);  
}

- (void)readDefaults 
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
  
  [defaults synchronize];

  entry = [defaults arrayForKey: @"GSMetadataIndexedPaths"];
  if (entry) {
    [indexedPaths addObjectsFromArray: entry];
  
  } else {
    NSArray *dirs;
    unsigned i;
    
    [indexedPaths addObject: NSHomeDirectory()];

    dirs = NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, 
                                                      NSAllDomainsMask, YES);
    [indexedPaths addObjectsFromArray: dirs];

    dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                                      NSAllDomainsMask, YES);
    for (i = 0; i < [dirs count]; i++) {
      NSString *dir = [dirs objectAtIndex: i];
      NSString *path = [dir stringByAppendingPathComponent: @"Headers"];

      if ([fm fileExistsAtPath: path]) {
        [indexedPaths addObject: path];
      }
      
      path = [dir stringByAppendingPathComponent: @"Documentation"];
      
      if ([fm fileExistsAtPath: path]) {
        [indexedPaths addObject: path];
      }
    }  
  }

  entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];
  if (entry) {
    [excludedPaths addObjectsFromArray: entry];
  }
  
  indexingEnabled = [defaults boolForKey: @"GSMetadataIndexingEnabled"];
  [enableSwitch setState: (indexingEnabled ? NSOnState : NSOffState)];
}

- (void)applyChanges
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUserDefaults *defaults;
  NSMutableDictionary *domain;
  NSMutableDictionary *info;

  defaults = [NSUserDefaults standardUserDefaults];
  [defaults synchronize];
  domain = [[defaults persistentDomainForName: NSGlobalDomain] mutableCopy];

  [domain setObject: indexedPaths forKey: @"GSMetadataIndexedPaths"];
  [domain setObject: excludedPaths forKey: @"GSMetadataExcludedPaths"];  
  [domain setObject: [NSNumber numberWithBool: indexingEnabled] 
             forKey: @"GSMetadataIndexingEnabled"];  

  [defaults setPersistentDomain: domain forName: NSGlobalDomain];
  [defaults synchronize];
  RELEASE (domain);  

  info = [NSMutableDictionary dictionary];

  [info setObject: indexedPaths forKey: @"GSMetadataIndexedPaths"];
  [info setObject: excludedPaths forKey: @"GSMetadataExcludedPaths"];  
  [info setObject: [NSNumber numberWithBool: indexingEnabled] 
           forKey: @"GSMetadataIndexingEnabled"];  

  [dnc postNotificationName: @"GSMetadataIndexedDirectoriesChanged"
	 								   object: nil 
                   userInfo: info];

  RELEASE (arp);
}

- (NSPreferencePaneUnselectReply)shouldUnselect
{
  return unselectReply;
}

@end


BOOL subPathOfPath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqual: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqual: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}

BOOL isDotFile(NSString *path)
{
  int len = ([path length] - 1);
  unichar c;
  int i;
  
  for (i = len; i >= 0; i--) {
    c = [path characterAtIndex: i];
    
    if (c == '.') {
      if ((i > 0) && ([path characterAtIndex: (i - 1)] == '/')) {
        return YES;
      }
    }
  }
  
  return NO;  
}


/*
- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(fswatcherConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self 
                isGlobalWatcher: NO];
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
          cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"GWorkspace"
                                 appName: @"fswatcher"
                               operation: NSLocalizedString(@"starting:", @"")
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];                  
          if (fsw) {
            [startAppWin updateProgressBy: 40.0 - i];
            break;
          }
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        fswnotifications = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact fswatcher\nfswatcher notifications disabled!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}
*/
