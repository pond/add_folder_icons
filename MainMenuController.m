//
//  MainMenuController.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 10/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "MainMenuController.h"

@implementation MainMenuController

/******************************************************************************\
 * -addUpdaterMenuEntriesWith: (#ifdef UPDATABLE)
 *
 * Call once and once only. Adds update-related menu items from the updater
 * to various application menus and sets actions where appropriate.
 *
 * It's nasty that we need this but initialisation order and the ownership of
 * different objects across different NIBs makes it particularly tricky to do
 * it cleanly any other way. The intention is that the application delegate,
 * when it gets notified that the application has started, instantiates the
 * update helper object and calls here. The delegate, main menu GUI elements
 * and main menu controller objects are all in the same NIB. We then call out
 * to the update helper, which 'owns' the update-related menu entries, giving
 * it references to the menus to which we want things adding and telling it
 * where in those menus to do that addition.
\******************************************************************************/

#ifdef UPDATABLE

    - ( void ) addUpdaterMenuEntriesWith: ( UpdateHelper * ) updateHelper
    {
        [ updateHelper addUpdateCheckTo: applicationMenu
                                atIndex: 1 ];

        [ updateHelper    addHelpItemTo: helpMenu
                                atIndex: 7
                             withAction: @selector( openWebSiteFromMenuItemToolTip: )
                               onTarget: self ];
    }

#endif

/******************************************************************************\
 * -openWebSiteFromMenuItemToolTip:
 *
 * Action which asks NSWorkspace to open a URL fetched from the sending menu
 * item's tooltip text. The idea is that you set up a menu item which will
 * link to some web site, with human-readable text for the menu item and a
 * helpful tooltip to let the user know which site it goes to.
 *
 * In: ( NSMenuItem * ) sender
 *     Sending menu item.
\******************************************************************************/

- ( IBAction ) openWebSiteFromMenuItemToolTip: ( NSMenuItem * ) sender
{
    [ [ NSWorkspace sharedWorkspace ] openURL: [ NSURL URLWithString: [ sender toolTip ] ] ];
}

@end
