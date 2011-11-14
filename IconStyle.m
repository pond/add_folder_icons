// 
//  IconStyle.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 20/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "IconStyle.h"
#import "FolderProcessNotificationProtocol.h" /* For APP_SERVER_CONNECTION_NAME only */

@implementation IconStyle 

/* Mandatory properties */

@dynamic createdAt;
@dynamic name;
@dynamic isPreset;
@dynamic usesSlipCover;

/* Properties only valid if style usesSlipCover */

@dynamic slipCoverName;

/* Properties only valid unless style usesSlipCover */

@dynamic cropToSquare;
@dynamic whiteBackground;
@dynamic dropShadow;
@dynamic randomRotation;
@dynamic maxImages;
@dynamic onlyUseCoverArt;
@dynamic showFolderInBackground;

/******************************************************************************\
 * -allocArgumentsUsing:withColourLabelsAsCoverArt:
 *
 * Return an array of arguments suitable for the icon generation command line
 * tool based on the settings for the current style. The array is suitable for
 * passing to something like NSTask as arguments for the command. Note that
 * this means argument processing, such as special quoting for pathnames, is
 * NOT performed.
 *
 * The caller is responsible for calling "-release" on the array when it is no
 * longer needed.
 *
 * In:  ( NSArray * ) coverArtFilenames
 *      Array of NSString pointers giving the leafnames for cover art.
 *      Optional; pass nil to omit from the command line string, which if
 *      passed to the icon generator tool would cause it to use its own
 *      internal default values;
 *
 *      ( BOOL ) includeColourLabels
 *      If YES and if the style dictates single image / cover art mode, then
 *      any file with a colour label, in addition to files identified by the
 *      leafname array given in the "coverArtFilenames" parameter above, will
 *      be treated as cover art; if NO, colour labels will be ignored.
 *
 * Out: ( NSArray * )
 *      Array of arguments. The caller must call "-release" on this when it is
 *      no longer needed.
\******************************************************************************/

- ( NSMutableArray * ) allocArgumentsUsing: ( NSArray * ) coverArtFilenames
                withColourLabelsAsCoverArt: ( BOOL      ) includeColourLabels
{
    NSMutableArray * arguments = [ [ NSMutableArray alloc ] initWithCapacity: 1 ];

    /* There is always a communications channel back to the application */

    [ arguments addObject: @"--communicate" ];
    [ arguments addObject: APP_SERVER_CONNECTION_NAME ];

    /* Even though at any particular 'time of writing' some options may
     * exclude others, we pass most parameters over to the CLI tool to make
     * sure that our defaults override any it might assert. So even though
     * the cover art filenames don't matter unless in single image mode,
     * say, we still pass it all in just in case future revisions use it.
     */

    if ( [ [ self usesSlipCover ] boolValue ] == YES )
    {
        [ arguments addObject: @"--slipcover" ];
        [ arguments addObject: [ self slipCoverName ] ];
    }

    if ( [ [ self cropToSquare    ] boolValue ] == YES ) [ arguments addObject: @"--crop"   ];
    if ( [ [ self whiteBackground ] boolValue ] == YES ) [ arguments addObject: @"--border" ]; /* (sic.) */
    if ( [ [ self dropShadow      ] boolValue ] == YES ) [ arguments addObject: @"--shadow" ];
        
    /* Some values only apply if in single image mode */

    if ( [ [ self onlyUseCoverArt ] boolValue ] == YES ) [ arguments addObject: @"--single" ];
    if ( includeColourLabels                    == YES ) [ arguments addObject: @"--labels" ];

    if ( [ coverArtFilenames count ] > 0 )
    {
        NSUInteger notNilCount = 0;

        /* This extra bit of messing around arises from the way the bindings
         * work in the Preferences panel dealing with cover art filenames. A
         * user can add a new entry but this just gives a null placeholder and
         * it's not enforced. The user may or may not fill it in.
         */

        //TODO: Figure out how to enforce non-null via validations despite
        //TODO: this being a dumb array<->controller<->view arrangement. Then
        //TODO: all the nil-checking code below can go away.

        for ( NSDictionary * entry in coverArtFilenames )
        {
            if ( [ entry objectForKey: @"leafname" ] != nil ) notNilCount ++;
        }

        if ( notNilCount > 0 )
        {
            [ arguments addObject: @"--coverart" ];
            [ arguments addObject: [ NSString stringWithFormat: @"%d", notNilCount ] ];
            
            for ( NSDictionary * entry in coverArtFilenames )
            {
                NSString * leafname = [ entry objectForKey: @"leafname" ];
                if ( leafname != nil ) [ arguments addObject: leafname ];
            }
        }
    }

    if ( [ [ self randomRotation ] boolValue ] == YES ) [ arguments addObject: @"--rotate" ];

    /* Values for showFolderInBackground / --showfolder must match as
     * all code related to this uses (or should be!) the enumeration
     * defined in "IconStyleShowFolderInBackground.h".
     */

    [ arguments addObject: @"--showfolder" ];
    [ arguments addObject: [ NSString stringWithFormat: @"%d", [ [ self showFolderInBackground ] intValue ] ] ];
    [ arguments addObject: @"--maximages"  ];
    [ arguments addObject: [ NSString stringWithFormat: @"%d", [ [ self maxImages ] intValue ] ] ];

    return arguments;
}

@end
