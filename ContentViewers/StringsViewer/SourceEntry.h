/* SourceEntry

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Alexander Malmberg <alexander@malmberg.org>
   Created: 2002

   This file is part of the GNUstep Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef SourceEntry_h
#define SourceEntry_h

@interface SourceEntry : NSObject
{
	NSString *file,*comment,*key;
	unsigned int line;
}

/* TODO: very cryptic error message if duplicate name in argument list,
gcc issue */
- initWithKey: (NSString *)k comment: (NSString *)c file: (NSString *)f line: (unsigned int)l;

-(NSString *) file;
-(NSString *) comment;
-(NSString *) key;
-(unsigned int) line;

@end

#endif

