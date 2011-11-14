//
//  NSImage+BrightnessContrast.m
//  SlipCover
//
//  Created by Pieter Omvlee on 3/11/09.
//  Copyright 2009 Bohemian Coding. All rights reserved.
//

#import "NSImage+BrightnessContrast.h"


@implementation NSImage (NSImage_BrightnessContrast)

- (NSImage *)sharpenedImage
{
  CIImage  *image  = [CIImage imageWithData:[self TIFFRepresentation]];
  CIFilter *filter = [CIFilter filterWithName:@"CISharpenLuminance"];
  
  [filter setValue:image forKey:@"inputImage"];
  [filter setValue:[NSNumber numberWithFloat:1.2] forKey:@"inputSharpness"];
  image = [filter valueForKey:@"outputImage"];
  
  NSImage *result = [[[NSImage alloc] initWithData:[[[[NSBitmapImageRep alloc] initWithCIImage:image] autorelease] TIFFRepresentation]] autorelease];
  
  return result;
}

- (NSData *)PNGRepresentationWithInterlaced:(BOOL)interlaced
{
  NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
  return [imageRep PNGRepresentationWithInterlaced:interlaced];
}

@end
