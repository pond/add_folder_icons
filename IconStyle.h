//
//  StyleIcon.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 20/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "IconStyleShowFolderInBackground.h"

@interface IconStyle : NSManagedObject  
{
}

/* Mandatory properties */

@property ( nonatomic, strong ) NSDate   * createdAt;
@property ( nonatomic, strong ) NSString * name;
@property ( nonatomic, strong ) NSNumber * isPreset;               /* Treat as BOOL */
@property ( nonatomic, strong ) NSNumber * usesSlipCover;          /* Treat as BOOL */
 
/* Properties only valid if style usesSlipCover */

@property ( nonatomic, strong ) NSString * slipCoverName;

/* Properties only valid unless style usesSlipCover */

@property ( nonatomic, strong ) NSNumber * cropToSquare;           /* Treat as BOOL */
@property ( nonatomic, strong ) NSNumber * whiteBackground;        /* Treat as BOOL */
@property ( nonatomic, strong ) NSNumber * dropShadow;             /* Treat as BOOL */
@property ( nonatomic, strong ) NSNumber * randomRotation;         /* Treat as BOOL */
@property ( nonatomic, strong ) NSNumber * onlyUseCoverArt;        /* Treat as BOOL */
@property ( nonatomic, strong ) NSNumber * maxImages;              /* Treat as NSUInteger */
@property ( nonatomic, strong ) NSNumber * showFolderInBackground; /* Treat as IconStyleShowFolderInBackground */

/* Useful methods */

- ( NSMutableArray * ) allocArgumentsUsing: ( NSArray * ) coverArtFilenames
                withColourLabelsAsCoverArt: ( BOOL      ) includeColourLabels;

@end
