//
//  CaseGenerator.m
//  SlipCover
//
//  Created by Pieter Omvlee on 2/9/09.
//  Copyright 2009 Bohemian Coding. All rights reserved.
//

#import "CaseGenerator.h"

@implementation CaseGenerator

// 2011-02-08 (ADH): Unused so commented out to avoid unneccessary supplementary
// code being included (e.g. IconFamily via Icon).
//+ (Icon *)caseImageWithCover:(NSImage *)cover caseDefinition:(CaseDefinition *)aCase
//{
//  NSMutableDictionary *images = [NSMutableDictionary dictionary];
//  
//  [images setValue:[self caseImageAtSize:case512 cover:cover caseDefinition:aCase] forKey:case512];
//  [images setValue:[self caseImageAtSize:case256 cover:cover caseDefinition:aCase] forKey:case256];
//  [images setValue:[self caseImageAtSize:case128 cover:cover caseDefinition:aCase] forKey:case128];
//  [images setValue:[self caseImageAtSize:case48 cover:cover caseDefinition:aCase] forKey:case48];
//  [images setValue:[self caseImageAtSize:case32 cover:cover caseDefinition:aCase] forKey:case32];
//  [images setValue:[self caseImageAtSize:case16 cover:cover caseDefinition:aCase] forKey:case16];
//  
//  return [Icon iconWithImages:images];
//}

+ (NSImage *)caseImageAtSize:(NSString *)caseSize cover:(NSImage *)cover caseDefinition:(CaseDefinition *)aCase
{
  NSImage *caseImage = [[aCase caseImageForSize:caseSize] copy];
  NSImage *maskImage = [aCase maskImageForSize:caseSize];
  
  if (!caseImage)
    return nil;
  
  if ([[NSSet setWithObjects:case48,case32,case16,nil] containsObject:caseSize])
    cover = [cover sharpenedImage];
  
  if (!maskImage) {
    maskImage = [[NSImage alloc] initWithSize:[caseImage size]];
    [maskImage lockFocus];
    [[NSColor blackColor] set];
    NSRectFill(NSMakeRect(0, 0, [caseImage size].width, [caseImage size].height));
    [maskImage unlockFocus];
  }
  
  //render cover on the mask
  [maskImage lockFocus];
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext] setShouldAntialias:YES];
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  // 2011-02-08 (ADH): Changed fromRect from
  // 'NSMakeRect(0, 0, [caseImage size].width, [caseImage size].height)'
  // to NSZeroRect, so that the supplied cover image is stretched to fill
  // the cover area. This is how the SlipCover application behaves. With
  // the code as supplied, only the top left corner of large images was
  // shown, without any scaling.
  [cover drawInRect:[aCase caseRectForSize:caseSize] fromRect:NSZeroRect operation:NSCompositeSourceIn fraction:1.0];
  [maskImage unlockFocus];
  
  [caseImage lockFocus];
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext] setShouldAntialias:YES];
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  
  int op = [aCase imageRendering] == ImageRenderingBottom ? NSCompositeDestinationOver : NSCompositeSourceOver;
  [maskImage drawInRect:[aCase caseRectForSize:caseSize] fromRect:[aCase caseRectForSize:caseSize] operation:op fraction:1.0];
  
  [NSGraphicsContext restoreGraphicsState];
  [caseImage unlockFocus];
  // [caseImage autorelease]; // 2012-02-04 (ADH): Commented out; this is implicit under ARC

  return caseImage;
}

// 2011-02-08 (ADH): Unused so commented out to avoid unneccessary supplementary
// code being included (e.g. IconFamily via Icon).
//+ (NSArray *)caseImagesWithCovers:(NSArray *)images caseDefinition:(CaseDefinition *)aCase
//{
//  NSMutableArray *result = [NSMutableArray array];
//  
//  for (NSImage *img in images) {
//    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//    [result addObject:[self caseImageWithCover:img caseDefinition:aCase]];
//    [pool release];
//  }
//  
//  return result;
//}

@end
