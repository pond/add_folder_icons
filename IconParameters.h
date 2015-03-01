/*
 *  IconParameters.h
 *  Add Folder Icons
 *
 *  Created by Andrew Hodgkinson on 30/01/2011.
 *  Copyright 2011 Hipposoft. All rights reserved.
 *
 */

#import "IconStyleShowFolderInBackground.h"
#import "CaseDefinition.h"

/* Simple structure to convey icon generation parameters */

@interface IconParameters : NSObject
{
}

@property                       BOOL                              previewMode;
@property ( strong, nonatomic ) CaseDefinition                  * slipCoverCase;
@property                       BOOL                              crop;
@property                       BOOL                              border;
@property                       BOOL                              shadow;
@property                       BOOL                              rotate;
@property                       NSUInteger                        maxImages;
@property                       IconStyleShowFolderInBackground   showFolderInBackground;
@property                       BOOL                              singleImageMode;
@property                       BOOL                              useColourLabels;
@property ( strong, nonatomic ) NSArray                         * coverArtNames;

@end
