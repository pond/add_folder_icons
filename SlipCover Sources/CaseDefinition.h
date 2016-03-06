//
//  CaseDefinition.h
//  SlipCover
//
//  Created by Pieter Omvlee on 2/9/09.
//  Copyright 2009 Bohemian Coding. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define caseDefinitonPathExtension @"case"

#define case512 @"512"
#define case256 @"256"
#define case128 @"128"
#define case48  @"48"
#define case32  @"32"
#define case16  @"16"

enum ImageRendering {
  ImageRenderingBottom = 0,
  ImageRenderingTop    = 1
};

@interface CaseDefinition : NSObject
{
  NSMutableDictionary *images;
  NSMutableDictionary *rects;
  NSMutableDictionary *masks;
  NSString            *name;
  
  int imageRendering;
  
  NSRect imageRect;
}
@property (readonly) NSString *name;

@property (readonly) NSDictionary *images;
@property (readonly) NSDictionary *rects;

@property (readonly) int imageRendering;

- (id)init NS_UNAVAILABLE; /* Use -initFromPath: instead */

+ (instancetype)caseDefinitionFromPath:(NSString *)path;
- (instancetype)initFromPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

- (NSImage *)caseImageForSize:(NSString *)caseSize;
- (NSRect)caseRectForSize:(NSString *)caseSize;

- (NSImage *)maskImageForSize:(NSString *)caseSize;

@end
