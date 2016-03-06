//
//  CustomIconGenerator.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 3/03/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IconStyle.h"
#import "CaseDefinition.h"

/* Border width around cropped images when at their intermediate stage of being
 * at full canvas size (see "GlobalConstants.h"); blur radius and offset for
 * shadows; padding to go around the border - must give room for the shadow and
 * the worst-case extra extent of the outer edge of the shadow due to +/- 0.075
 * radian (~4.5 degree) rotation. Values in pixels.
 *
 * If you change these, make sure you update "locations" below too.
 */

#define THUMB_BORDER 20
#define BLUR_RADIUS  16
#define BLUR_OFFSET   8
#define ROTATION_PAD 40

/* Image search loop exit conditions (values are inclusive); zero equals
 * unlimited in either case (not recommended...).
 */

#define MAXIMUM_IMAGE_SIZE      67108864 /* 64MiB */
#define MAXIMUM_IMAGES_FOUND    5000
#define MAXIMUM_LOOP_TIME_TICKS CLOCKS_PER_SEC /* I.e. 1 second */

/* The class interface itself */

@interface CustomIconGenerator : NSObject

    - ( instancetype ) init NS_UNAVAILABLE; /* Use -initWithIconStyle:... instead */
    - ( instancetype ) initWithIconStyle: ( IconStyle * ) theIconStyle
                            forPOSIXPath: ( NSString  * ) thePosixPath;

    - ( CGImageRef   )          generate: ( NSError ** ) error;

    /* These properties record things that were given in the constructor */

    @property ( nonatomic, retain, readonly ) IconStyle * iconStyle;
    @property ( nonatomic, retain, readonly ) NSString  * posixPath;

    /* The CaseDefinition instance corresponding to the named Slip Cover case
     * style in the IconStyle data given via the constructor and read via the
     * 'iconStyle' property. If the style does not describe a Slip Cover case,
     * this will be 'nil'.
     */

    @property ( nonatomic, retain, readonly ) CaseDefinition * slipCoverCase;

    /* These read-only properties are taken from the user defaults at the
     * moment of instantiation and cached inside it. Subsequent changes to
     * the preferences don't alter this instance's behaviour.
     */

    @property ( nonatomic, retain, readonly ) NSArray * coverArtFilenames;
    @property (                    readonly ) BOOL      useColourLabelsToIdentifyCoverArt;

    /* These read/write properties can be changed once an instance has been
     * created. They all default to NO.
     */

    @property BOOL makeBackgroundOpaque;
    @property BOOL nonRandomImageSelectionForAPreview;

    /* If building a preview you may want to know for sure which cover art
     * filenames are in use, since the user might change them to anything.
     * You can override the cover art user preferences array here. Specify
     * an array of one or more leafnames without extensions - e.g.
     * @[ @"folder", @"cover" ].
     */

    @property ( nonatomic, retain ) NSArray * overrideCoverArtFilenames;

@end
