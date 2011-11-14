//
//  CaseDefinition.m
//  SlipCover
//
//  Created by Pieter Omvlee on 2/9/09.
//  Copyright 2009 Bohemian Coding. All rights reserved.
//

#import "CaseDefinition.h"


@implementation CaseDefinition

@synthesize name, images, rects, imageRendering;

+ (id)caseDefinitionFromPath:(NSString *)path
{
  return [[[CaseDefinition alloc] initFromPath:path] autorelease];
}

// 2011-01-06 (ADH): Fixed to remove deprecations and replace extensions of
// Cocoa classes like NSString with locally coded equivalents:
// 
// Use of NSFileManager +defaultManager - changed to +alloc/-init/-autorelease
// Use of directoryContentsAtPath - changed to contentsOfDirectoryAtPath:error:
// Custom extension NSString -startsWith: @"." replaced by equivalent,
//   -characterAtIndex:0 equal to '.'
// Custom extension NSImage +imageFromPath: replaced by equivalent,
//   +alloc/-initWithContentsOfFile/-autorelease
// 
// Modified also the method so that it wraps itself in a try/catch block which
// ignores exceptions. Makes sure that 'name' is only set if the object was
// correctly initialised - callers receiving an object with a nil 'name' can
// discard it.
// 
// It's odd that property 'name' was left uninitialised in this code and since
// it is read-only, cannot be set externally. Either the SlipCover application
// doesn't use this and displays menus of names from some other source, or the
// source herein differs from that in the application. Either way, I've added
// a further change which initialises the name based on the path.

- (id)initFromPath:(NSString *)path
{
  self = [super init];
  
  if ([[path pathExtension] isEqual:caseDefinitonPathExtension]) {
    
    @try {

      NSFileManager * fileManager = [[[NSFileManager alloc] init] autorelease];
      images = [[NSMutableDictionary alloc] init];
      masks  = [[NSMutableDictionary alloc] init];
      
      //images
      NSString *imagePath = [path stringByAppendingPathComponent:@"images"];
      NSArray *names      = [fileManager contentsOfDirectoryAtPath:imagePath error:NULL];
      for (NSString *n in names) {
        if ([n characterAtIndex:0] == '.') continue;
        NSImage *img = [[[NSImage alloc] initWithContentsOfFile:[imagePath stringByAppendingPathComponent:n]] autorelease];
        [images setValue:img forKey:[n stringByDeletingPathExtension]];
      }
      
      //masks
      NSString *maskPath = [path stringByAppendingPathComponent:@"masks"];
      names              = [fileManager contentsOfDirectoryAtPath:maskPath error:NULL];
      for (NSString *n in names) {
        if ([n characterAtIndex:0] == '.') continue;
        NSImage *img = [[[NSImage alloc] initWithContentsOfFile:[maskPath stringByAppendingPathComponent:n]] autorelease];
        [masks setValue:img forKey:[n stringByDeletingPathExtension]];
      }
      
      //rects
      rects = [[NSMutableDictionary alloc] initWithContentsOfFile:[path stringByAppendingPathComponent:@"rectangles.xml"]];
      
      imageRendering = [[rects valueForKey:@"imageRendering"] isEqual:@"top"];
      [rects setValue:nil forKey:@"imageRendering"];

      //very last step...
      if ([images count] > 0 && [rects count] > 0) name = [[[path stringByDeletingPathExtension] lastPathComponent] retain];
    }
    @catch (NSException * e) {
      (void ) e;
    }
  }

  return self;
}

- (NSImage *)caseImageForSize:(NSString *)caseSize
{
  return [images valueForKey:caseSize];
}

- (NSImage *)maskImageForSize:(NSString *)caseSize
{
  return [masks valueForKey:caseSize];
}

- (NSRect)caseRectForSize:(NSString *)caseSize
{
  return NSRectFromString([rects valueForKey:caseSize]);
}

@end
