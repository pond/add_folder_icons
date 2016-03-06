//
//  Add_Folder_IconsAppDelegate.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 14/03/2010.
//  Copyright 2010, 2011 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IconStyleManager.h"
#import "MainMenuController.h"
#import "SplashWindowController.h"
#import "MainWindowController.h"
#import "ManageStylesWindowController.h"
#import "ApplicationSpecificPreferencesWindowController.h"

#ifdef UPDATABLE
    #import "UpdateHelper.h"
#endif

#define SPLASH_WINDOW_CONTROLLER_NIB_NAME @"SplashWindow"
#define MAIN_WINDOW_CONTROLLER_NIB_NAME   @"MainWindow"
#define MANAGE_STYLES_CONTROLLER_NIB_NAME @"ManageStyles"

@interface Add_Folder_IconsAppDelegate : NSObject < NSApplicationDelegate >
{
    IBOutlet MainMenuController  * mainMenuController;

    IconStyleManager             * iconStyleManager;
    MainWindowController         * mainWindowController;
    ManageStylesWindowController * manageStylesWindowController;
    SplashWindowController       * splashWindowController;

    #ifdef UPDATABLE
        UpdateHelper             * updateHelper;
    #endif
}

#ifdef UPDATABLE
    @property ( readonly ) UpdateHelper * updateHelper;
#endif

- ( void       ) establishDefaultPreferences;
- ( CGImageRef ) standardFolderIcon;

- ( IBAction   ) showPreferences:  ( id ) sender;
- ( IBAction   ) showManageStyles: ( id ) sender;

@end
