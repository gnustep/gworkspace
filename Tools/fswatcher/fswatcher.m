/* fswatcher.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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

#include "fswatcher.h"
#include "GNUstep.h"

#include <stdio.h>
#include <unistd.h>
#ifdef __MINGW__
  #include "process.h"
#endif
#include <fcntl.h>
#ifdef HAVE_SYSLOG_H
  #include <syslog.h>
#endif
#include <signal.h>


@implementation	FSWClientInfo

- (void)dealloc
{
	TEST_RELEASE (conn);
	TEST_RELEASE (client);
  RELEASE (wpaths);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
		client = nil;
		conn = nil;
    wpaths = [NSMutableArray new];
  }
  
  return self;
}

- (void)setConnection:(NSConnection *)connection
{
	ASSIGN (conn, connection);
}

- (NSConnection *)connection
{
	return conn;
}

- (void)setClient:(id <FSWClientProtocol>)clnt
{
	ASSIGN (client, clnt);
}

- (id <FSWClientProtocol>)client
{
	return client;
}

- (void)addWatchedPath:(NSString *)path
{
  [wpaths addObject: path];
}

- (void)removeWatchedPath:(NSString *)path
{
  int count = [wpaths count];
  int i;
  
  for (i = count - 1; i >= 0; i--) {
    NSString *wpath = [wpaths objectAtIndex: i];
  
    if ([wpath isEqual: path]) {
      [wpaths removeObjectAtIndex: i];
      break;
    }
  }
}

- (BOOL)isWathchingPath:(NSString *)path
{
  return [wpaths containsObject: path];
}

- (NSArray *)watchedPaths
{
  return wpaths;
}

@end


@implementation	FSWatcher

- (void)dealloc
{
  int i;
  
  if (conn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: conn];
    DESTROY (conn);
  }

	for (i = 0; i < [clientsInfo count]; i++) {
		NSConnection *connection = [[clientsInfo objectAtIndex: i] connection];
    
		if (connection) {
      [nc removeObserver: self
		                name: NSConnectionDidDieNotification
		              object: conn];
		}
	}
  
  RELEASE (clientsInfo);
  RELEASE (watchers);

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {    
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    
    clientsInfo = [NSMutableArray new];
    
    watchers = [NSMutableArray new];

    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"fswatcher"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
      
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];
  }
  
  return self;    
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  FSWClientInfo *info = [FSWClientInfo new];
	      
  [info setConnection: newConn];
  [clientsInfo addObject: info];
  RELEASE (info);

  [nc addObserver: self
         selector: @selector(connectionBecameInvalid:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  return YES;
}

- (void)connectionBecameInvalid:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  if (connection == conn) {
    NSLog(@"argh - fswatcher server root connection has been destroyed.");
    exit(EXIT_FAILURE);
    
  } else {
		FSWClientInfo *info = [self clientInfoWithConnection: connection];
	
		if (info) {
      NSArray *wpaths = [info watchedPaths];
      int i;
    
      for (i = 0; i < [wpaths count]; i++) {
        NSString *wpath = [wpaths objectAtIndex: i];
        Watcher *watcher = [self watcherForPath: wpath];
      
        if (watcher) {
          [watcher removeListener];
        }
      }  
    
			[clientsInfo removeObject: info];
		}
	}
}

- (void)registerClient:(id <FSWClientProtocol>)client
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];

	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"registration with unknown connection"];
  }

  if ([info client] != nil) { 
    [NSException raise: NSInternalInconsistencyException
		            format: @"registration with registered client"];
  }

  if ([(id)client isProxy] == YES) {
    [(id)client setProtocolForProxy: @protocol(FSWClientProtocol)];
    [info setClient: client];  
  }
}

- (void)unregisterClient:(id <FSWClientProtocol>)client
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];
  NSArray *wpaths;
  int i;

	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"unregistration with unknown connection"];
  }

  if ([info client] == nil) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"unregistration with unregistered client"];
  }

  wpaths = [info watchedPaths];
  
  for (i = 0; i < [wpaths count]; i++) {
    NSString *wpath = [wpaths objectAtIndex: i];
    Watcher *watcher = [self watcherForPath: wpath];

    if (watcher) {
  //    NSLog(@"removing listener for: %@", wpath);
      [watcher removeListener];
    }
  }  

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  [clientsInfo removeObject: info];  
}

- (FSWClientInfo *)clientInfoWithConnection:(NSConnection *)connection
{
	int i;

	for (i = 0; i < [clientsInfo count]; i++) {
		FSWClientInfo *info = [clientsInfo objectAtIndex: i];
    
		if ([info connection] == connection) {
			return info;
		}
	}

	return nil;
}

- (FSWClientInfo *)clientInfoWithRemote:(id)remote
{
	int i;

	for (i = 0; i < [clientsInfo count]; i++) {
		FSWClientInfo *info = [clientsInfo objectAtIndex: i];
    
		if ([info client] == remote) {
			return info;
		}
	}

	return nil;
}

- (void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];
  Watcher *watcher = [self watcherForPath: path];

	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"adding watcher from unknown connection"];
  }

  if ([info client] == nil) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"adding watcher for unregistered client"];
  }

//  NSLog(@"addWatcherForPath %@", path);
  
  if (watcher) {
    [info addWatchedPath: path];
    [watcher addListener]; 
        
  } else {
    if ([fm fileExistsAtPath: path]) {
      [info addWatchedPath: path];
  	  watcher = [[Watcher alloc] initWithWatchedPath: path fswatcher: self];      
  	  [watchers addObject: watcher];
  	  RELEASE (watcher);  
    }
  }
}

- (void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path
{
	NSConnection *connection = [(NSDistantObject *)client connectionForProxy];
  FSWClientInfo *info = [self clientInfoWithConnection: connection];
  Watcher *watcher = [self watcherForPath: path];
  
	if (info == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"removing watcher from unknown connection"];
  }

  if ([info client] == nil) { 
    [NSException raise: NSInternalInconsistencyException
                format: @"removing watcher for unregistered client"];
  }  
  
//  NSLog(@"removeWatcherForPath %@", path);
  
  if (watcher && ([watcher isOld] == NO)) {
    [info removeWatchedPath: path];
  	[watcher removeListener];  
  }
}

- (Watcher *)watcherForPath:(NSString *)path
{
  int i;

  for (i = 0; i < [watchers count]; i++) {
    Watcher *watcher = [watchers objectAtIndex: i];    
    if ([watcher isWathcingPath: path] && ([watcher isOld] == NO)) { 
      return watcher;
    }
  }
  
  return nil;
}

- (void)watcherTimeOut:(id)sender
{
  Watcher *watcher = (Watcher *)[sender userInfo];

  if ([watcher isOld]) {
    [self removeWatcher: watcher];
  } else {
    [watcher watchFile];
  }
}

- (void)removeWatcher:(Watcher *)watcher
{
	NSTimer *timer = [watcher timer];

	if (timer && [timer isValid]) {
		[timer invalidate];
	}
  
  [watchers removeObject: watcher];
}

- (void)watcherNotification:(NSDictionary *)info
{
  int event = [[info objectForKey: @"event"] intValue];
  NSString *path = [info objectForKey: @"path"];
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSData *data;
  int i;
  
  [dict setObject: path forKey: @"path"];
  
  if (event == WatchedDirDeleted) {
    [dict setObject: @"GWWatchedDirectoryDeleted" forKey: @"event"];  
  } else if (event == FilesDeletedInWatchedDir) {
    [dict setObject: @"GWFileDeletedInWatchedDirectory" forKey: @"event"];
    [dict setObject: [info objectForKey: @"files"] forKey: @"files"];
  } else if (event == FilesCreatedInWatchedDir) {
    [dict setObject: @"GWFileCreatedInWatchedDirectory" forKey: @"event"];
    [dict setObject: [info objectForKey: @"files"] forKey: @"files"];
  } else if (event == WatchedFileDeleted) {
    [dict setObject: @"GWWatchedFileDeleted" forKey: @"event"];  
  } else if (event == WatchedFileModified) {
    [dict setObject: @"GWWatchedFileModified" forKey: @"event"];  
  }

  data = [NSArchiver archivedDataWithRootObject: dict];
  
	for (i = 0; i < [clientsInfo count]; i++) {
		FSWClientInfo *info = [clientsInfo objectAtIndex: i];
    
		if ([info isWathchingPath: path]) {
			[[info client] watchedPathDidChange: data];
		}
	}
}

@end


@implementation Watcher

- (void)dealloc
{ 
	if (timer && [timer isValid]) {
		[timer invalidate];
	}
  RELEASE (watchedPath);  
  TEST_RELEASE (pathContents);
  RELEASE (date);  
  [super dealloc];
}

- (id)initWithWatchedPath:(NSString *)path
                fswatcher:(id)fsw
{
  self = [super init];
  
  if (self) { 
		NSDictionary *attributes;
		NSString *type;
    		
    ASSIGN (watchedPath, path);    
		fm = [NSFileManager defaultManager];	
    attributes = [fm fileAttributesAtPath: path traverseLink: YES];
    type = [attributes fileType];
		ASSIGN (date, [attributes fileModificationDate]);		
    
    if (type == NSFileTypeDirectory) {
		  ASSIGN (pathContents, ([fm directoryContentsAtPath: watchedPath]));
      isdir = YES;
    } else {
      isdir = NO;
    }
    
    listeners = 1;
		isOld = NO;
    fswatcher = fsw;
    timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
												                     target: fswatcher 
                                           selector: @selector(watcherTimeOut:) 
										                       userInfo: self 
                                            repeats: YES];
  }
  
  return self;
}

- (void)watchFile
{
  NSDictionary *attributes;
  NSDate *moddate;
  NSMutableDictionary *notifdict;

	if (isOld) {
		return;
	}
	
	attributes = [fm fileAttributesAtPath: watchedPath traverseLink: YES];

  if (attributes == nil) {
    notifdict = [NSMutableDictionary dictionary];
    [notifdict setObject: watchedPath forKey: @"path"];
    
    if (isdir) {
      [notifdict setObject: [NSNumber numberWithInt: WatchedDirDeleted] 
                    forKey: @"event"];
    } else {
      [notifdict setObject: [NSNumber numberWithInt: WatchedFileDeleted] 
                    forKey: @"event"];
    }
    
    [fswatcher watcherNotification: notifdict];              
		isOld = YES;
    return;
  }
  	
  moddate = [attributes fileModificationDate];

  if ([date isEqualToDate: moddate] == NO) {
    if (isdir) {
      NSArray *oldconts = [pathContents copy];
      NSArray *newconts = [fm directoryContentsAtPath: watchedPath];	
      NSMutableArray *diffFiles = [NSMutableArray array];
      int i;

      ASSIGN (date, moddate);	
      ASSIGN (pathContents, newconts);

      notifdict = [NSMutableDictionary dictionary];
      [notifdict setObject: watchedPath forKey: @"path"];

		  /* if there is an error in fileAttributesAtPath */
		  /* or watchedPath doesn't exist anymore         */
		  if (newconts == nil) {	
        [notifdict setObject: [NSNumber numberWithInt: WatchedDirDeleted] 
                      forKey: @"event"];
        [fswatcher watcherNotification: notifdict];
        RELEASE (oldconts);
			  isOld = YES;
    	  return;
		  }

      for (i = 0; i < [oldconts count]; i++) {
        NSString *fname = [oldconts objectAtIndex: i];
        if ([newconts containsObject: fname] == NO) {
          [diffFiles addObject: fname];
        }
      }

      if ([diffFiles count] > 0) {
        [notifdict setObject: [NSNumber numberWithInt: FilesDeletedInWatchedDir] 
                      forKey: @"event"];
        [notifdict setObject: diffFiles forKey: @"files"];
        [fswatcher watcherNotification: notifdict];
      }

      diffFiles = [NSMutableArray array];

      for (i = 0; i < [newconts count]; i++) {
        NSString *fname = [newconts objectAtIndex: i];
        if ([oldconts containsObject: fname] == NO) {   
          [diffFiles addObject: fname];
        }
      }

      if ([diffFiles count] > 0) {
        [notifdict setObject: watchedPath forKey: @"path"];
        [notifdict setObject: [NSNumber numberWithInt: FilesCreatedInWatchedDir] 
                      forKey: @"event"];
        [notifdict setObject: diffFiles forKey: @"files"];
        [fswatcher watcherNotification: notifdict];
      }

      TEST_RELEASE (oldconts);	
      	
	  } else {  // isdir == NO
      ASSIGN (date, moddate);	
      
      notifdict = [NSMutableDictionary dictionary];
      
      [notifdict setObject: watchedPath forKey: @"path"];
      [notifdict setObject: [NSNumber numberWithInt: WatchedFileModified] 
                    forKey: @"event"];
                    
      [fswatcher watcherNotification: notifdict];
    }
  } 
}

- (void)addListener
{
  listeners++;
}

- (void)removeListener
{ 
  listeners--;
  if (listeners <= 0) { 
		isOld = YES;
  } 
}

- (BOOL)isWathcingPath:(NSString *)apath
{
  return ([apath isEqualToString: watchedPath]);
}

- (NSString *)watchedPath
{
	return watchedPath;
}

- (BOOL)isOld
{
	return isOld;
}

- (NSTimer *)timer
{
  return timer;
}

@end


int main(int argc, char** argv)
{
	FSWatcher *fsw;

	switch (fork()) {
	  case -1:
	    fprintf(stderr, "fswatcher - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    setsid();
	    break;

	  default:
	    exit(0);
	}
  
  CREATE_AUTORELEASE_POOL (pool);
	fsw = [[FSWatcher alloc] init];
  RELEASE (pool);
  
  if (fsw != nil) {
	  CREATE_AUTORELEASE_POOL (pool);
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(0);
}

/*
static void init(int argc, char** argv, char **env)
{
  NSProcessInfo *pInfo = [NSProcessInfo processInfo];
  NSMutableArray *args = [pInfo arguments];
  BOOL shouldFork = YES;

  if (([args count] > 1) && [[args objectAtIndex: 1] isEqual: @"--daemon"]) {
    NSLog(@"beccato --daemon");
    shouldFork = NO;
  }
      
  if (shouldFork) {
    NSFileHandle *nullHandle;
    NSTask *task;
    
    NS_DURING
	    {
        task = [NSTask new];
	      [task setLaunchPath: [[NSBundle mainBundle] executablePath]];
	      [task setArguments: [NSArray arrayWithObject: @"--daemon"]];
	      [task setEnvironment: [pInfo environment]];
	      nullHandle = [NSFileHandle fileHandleWithNullDevice];
	      [task setStandardInput: nullHandle];
	      [task setStandardOutput: nullHandle];
	      [task setStandardError: nullHandle];
	      [task launch];
	      DESTROY(task);
      }
    NS_HANDLER
      {
	      DESTROY(task);
	    }
    NS_ENDHANDLER
    
    NSLog(@"QUA 1");
    
    exit(0);
  }

    NSLog(@"QUA 2 (daemon)");
}

int main(int argc, char** argv, char **env)
{
  CREATE_AUTORELEASE_POOL (pool);
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	FSWatcher *fsw;

  init(argc, argv, env);

 defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
      @"YES", @"GSLogSyslog", nil]];
  
	fsw = [[FSWatcher alloc] init];


    [[NSFileHandle fileHandleWithStandardInput] closeFile];
    [[NSFileHandle fileHandleWithStandardOutput] closeFile];
#ifndef __MINGW__
//    if (debugging == NO)
 //     {
	[[NSFileHandle fileHandleWithStandardError] closeFile];
 //     }
#endif


  RELEASE (pool);
  
  if (fsw != nil) {
    CREATE_AUTORELEASE_POOL(pool);
    [[NSRunLoop currentRunLoop] run];
    RELEASE(pool);
  }
    
  exit(EXIT_SUCCESS);
}

*/
