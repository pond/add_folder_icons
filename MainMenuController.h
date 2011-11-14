//
//  MainMenuController.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 10/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef UPDATABLE
    #import "UpdateHelper.h"
#endif

@interface MainMenuController : NSObject < NSMenuDelegate >
{
    IBOutlet NSMenu * applicationMenu;
    IBOutlet NSMenu * helpMenu;
}

#ifdef UPDATABLE
    - ( void ) addUpdaterMenuEntriesWith: ( UpdateHelper * ) updateHelper;
#endif

- ( IBAction ) openWebSiteFromMenuItemToolTip: ( NSMenuItem * ) sender;

@end
