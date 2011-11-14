//
//  GenericPreferencesWindowController.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 12/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//
//  Based on ideas from "DBPrefsWindowController" by Dave Batton,
//  http://www.Mere-Mortal-Software.com/blog/
//
//  Unwanted features removed, some code reorganisation and some
//  names changed for wider application code style consistency.
//

#import <Cocoa/Cocoa.h>

#define GENERIC_PREFERENCES_WINDOW_CONTROLLER_NIB_NAME           @"Preferences"
#define GENERIC_PREFERENCES_WINDOW_CONTROLLER_TOOLBAR_IDENTIFIER @"PreferencesToolbar"

@interface GenericPreferencesWindowController : NSWindowController < NSToolbarDelegate >
{
    NSMutableArray      * toolbarLabels;
    NSMutableDictionary * toolbarViews;
    NSMutableDictionary * toolbarItems;

    NSView              * subview;
}

+ ( id ) allocPreferencesWindowController;

- ( void   ) initToolbar;
- ( void   ) addView:             ( NSView   * ) view label: ( NSString * ) label;
- ( void   ) addView:             ( NSView   * ) view label: ( NSString * ) label image: ( NSImage * ) image;

- ( void   ) displayViewForLabel: ( NSString * ) label animate: ( BOOL ) animate;
- ( NSRect ) frameForView:        ( NSView   * ) view;

@end
