//
//  NSImage+BrightnessContrast.h
//  SlipCover
//
//  Created by Pieter Omvlee on 3/11/09.
//  Copyright 2009 Bohemian Coding. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface NSImage (NSImage_BrightnessContrast)
- (NSImage *)sharpenedImage;
- (NSData *)PNGRepresentationWithInterlaced:(BOOL)interlaced;
@end
