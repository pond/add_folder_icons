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

typedef struct IconParameters
{
    NSString                        * commsChannel; /* Used when in slave mode to the GUI */
    BOOL                              previewMode;  /* Used for GUI icon style preview generation */

    CaseDefinition                  * slipCoverCase;
    BOOL                              crop;
    BOOL                              border;
    BOOL                              shadow;
    BOOL                              rotate;
    NSUInteger                        maxImages;
    IconStyleShowFolderInBackground   showFolderInBackground;
    BOOL                              singleImageMode;
    BOOL                              useColourLabels;
    NSMutableArray                  * coverArtNames;
}
IconParameters;
