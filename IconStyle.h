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

@property ( nonatomic, retain ) NSDate   * createdAt;
@property ( nonatomic, retain ) NSString * name;
@property ( nonatomic, retain ) NSNumber * isPreset;               /* Treat as BOOL */
@property ( nonatomic, retain ) NSNumber * usesSlipCover;          /* Treat as BOOL */
 
/* Properties only valid if style usesSlipCover */

@property ( nonatomic, retain ) NSString * slipCoverName;

/* Properties only valid unless style usesSlipCover */

@property ( nonatomic, retain ) NSNumber * cropToSquare;           /* Treat as BOOL */
@property ( nonatomic, retain ) NSNumber * whiteBackground;        /* Treat as BOOL */
@property ( nonatomic, retain ) NSNumber * dropShadow;             /* Treat as BOOL */
@property ( nonatomic, retain ) NSNumber * randomRotation;         /* Treat as BOOL */
@property ( nonatomic, retain ) NSNumber * onlyUseCoverArt;        /* Treat as BOOL */
@property ( nonatomic, retain ) NSNumber * maxImages;              /* Treat as NSUInteger */
@property ( nonatomic, retain ) NSNumber * showFolderInBackground; /* Treat as IconStyleShowFolderInBackground */

/* Useful methods */

- ( NSMutableArray * ) allocArgumentsUsing: ( NSArray * ) coverArtFilenames
                withColourLabelsAsCoverArt: ( BOOL      ) includeColourLabels;

@end
