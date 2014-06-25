//
//  UpdateHelper.h
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
//  As recommended in comments in the ".m" file, though, a belt-and-braces
//  approach couples this with conditionally compiled elements for a truly
//  clean result in "non-updatable" variants.
//

#import <Cocoa/Cocoa.h>

@interface UpdateHelper : NSViewController
{
    IBOutlet NSMenuItem * __unsafe_unretained checkForUpdatesMenuItem;
    IBOutlet NSMenuItem * __unsafe_unretained helpAboutUpdaterMenuItem;
}

/* Properties */

@property ( unsafe_unretained, readonly ) NSMenuItem * checkForUpdatesMenuItem;
@property ( unsafe_unretained, readonly ) NSMenuItem * helpAboutUpdaterMenuItem;

/* General methods */

- ( void )    addHelpItemTo: ( NSMenu     * ) menu
                    atIndex: ( NSUInteger   ) index
                 withAction: ( SEL          ) selector
                   onTarget: ( id           ) target;

- ( void ) addUpdateCheckTo: ( NSMenu     * ) menu
                    atIndex: ( NSUInteger   ) index;

@end
