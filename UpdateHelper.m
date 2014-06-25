//
//  UpdateHelper.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 11/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//
//  This approach to the run-time conditional use of Sparkle is based with
//  thanks on the idea presented here:
//
//    http://danielkennett.org/blog/2010/12/techniques-for-managing-optional-code/
//
//  As recommended in comments below, though, a belt-and-braces approach
//  couples this with conditionally compiled elements for a truly clean
//  result in "non-updatable" variants with this source file only included
//  in targets that definitely need it.
//

#import "UpdateHelper.h"

#define UPDATES_NIB_NAME   @"Updates"
#define UPDATER_CLASS_NAME @"SUUpdater"

@implementation UpdateHelper

@synthesize checkForUpdatesMenuItem,
            helpAboutUpdaterMenuItem;

/******************************************************************************\
 * -init
 *
 * If and only if a Sparkle updater class can be found, return a non-nil
 * result having loaded the "Updates" NIB containing all GUI fragments related
 * to updates for "UPDATABLE" builds.
 *
 * Out: ( id )
 *      Instance, or 'nil' if there's apparently no Sparkle framework present.
 *      In theory this alone could be used to switch update-based behaviour on
 *      or off, but for a truly clean non-updatable build, conditionally
 *      compile all update-related code by wrapping it in "#if[n]def UPDATABLE"
 *      as well as checking for 'nil' return values within that code.
\******************************************************************************/

- ( id ) init
{
    if ( NSClassFromString( UPDATER_CLASS_NAME ) == nil )
    {
        return nil;
    }

    if ( ( self = [ super initWithNibName: UPDATES_NIB_NAME bundle: nil ] ) )
    {
        [ self view ];
    }

    return self;
}

/******************************************************************************\
 * -addHelpItemTo:atIndex:withAction:
 *
 * Add the UpdateHelper's "Help about Sparkle" menu item from its NIB into the
 * given menu the given index and assign an action of the given selector to be
 * sent to the given object.
 *
 * In: ( NSMenu * ) menu
 *     Menu to which the item should be added;
 *
 *     ( NSUInteger ) index
 *     Index at which the item should be added;
 *
 *     ( SEL ) selector
 *     Action selector to assign;
 *
 *     ( id ) target
 *     Target object to which action selector message should be sent.
\******************************************************************************/

- ( void ) addHelpItemTo: ( NSMenu     * ) menu
                 atIndex: ( NSUInteger   ) index
              withAction: ( SEL          ) selector
                onTarget: ( id           ) target
{
    [ helpAboutUpdaterMenuItem setAction: selector ];
    [ helpAboutUpdaterMenuItem setTarget: target   ];

    [ menu insertItem: helpAboutUpdaterMenuItem atIndex: index ];
}

/******************************************************************************\
 * -addUpdateCheckTo:atIndex:
 *
 * Add the UpdateHelper's "Check For Updates..." menu item from its NIB into
 * the given menu at the given index. The menu item is automatically bound to
 * the Sparkle "check for updates" action.
 *
 * In: ( NSMenu * ) menu
 *     Menu to which the item should be added;
 *
 *     ( NSUInteger ) index
 *     Index at which the item should be added.
\******************************************************************************/

- ( void ) addUpdateCheckTo: ( NSMenu     * ) menu
                    atIndex: ( NSUInteger   ) index
{
    [ menu insertItem: checkForUpdatesMenuItem atIndex: index ];
}

@end
