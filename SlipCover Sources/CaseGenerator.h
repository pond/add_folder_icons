//
//  CaseGenerator.h
//  SlipCover
//
//  Created by Pieter Omvlee on 2/9/09.
//  Copyright 2009 Bohemian Coding. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// 2011-02-08 (ADH): Unused so commented out to avoid unneccessary supplementary
// code being included (e.g. IconFamily via Icon).
//#import "Icon.h"
#import "CaseDefinition.h"
#import "NSImage+BrightnessContrast.h"

@interface CaseGenerator : NSObject
{
  
}
// 2011-02-08 (ADH): Unused so commented out to avoid unneccessary supplementary
// code being included (e.g. IconFamily via Icon).
//+ (Icon *)caseImageWithCover:(NSImage *)cover caseDefinition:(CaseDefinition *)aCase;
//+ (NSArray *)caseImagesWithCovers:(NSArray *)images caseDefinition:(CaseDefinition *)aCase;

//private
+ (NSImage *)caseImageAtSize:(NSString *)caseSize cover:(NSImage *)cover caseDefinition:(CaseDefinition *)aCase;
@end
