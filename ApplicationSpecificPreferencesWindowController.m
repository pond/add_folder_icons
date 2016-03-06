//
//  ApplicationSpecificPreferencesWindowController.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 13/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "ApplicationSpecificPreferencesWindowController.h"

#ifdef UPDATABLE
    #import "Add_Folder_IconsAppDelegate.h"
    #import "UpdateHelper.h"
#endif

@implementation ApplicationSpecificPreferencesWindowController

@synthesize iconStyleManager,
            managedObjectContext,
            managedObjectModel;

/******************************************************************************\
 * +applicationSpecificPreferencesWindowController:
 *
 * Obtain a pointer to the preferences controller. Since the application's
 * preferences include settings related to icon styles which are managed in
 * the shared CoreData pool, a reference to the IconStyleManager singleton
 * is obtained in passing (thus creating that style manager if need be).
 *
 * Out: ( ApplicationSpecificPreferencesWindowController * )
 *      Pointer to a singleton instance of the preferences controller.
\******************************************************************************/

static ApplicationSpecificPreferencesWindowController * applicationSpecificPreferencesWindowControllerSingletonInstance = nil;

+ ( ApplicationSpecificPreferencesWindowController * ) applicationSpecificPreferencesWindowController
{
    if ( applicationSpecificPreferencesWindowControllerSingletonInstance == nil )
    {
        applicationSpecificPreferencesWindowControllerSingletonInstance =
        [
            [ self alloc ] initWithWindowNibName: GENERIC_PREFERENCES_WINDOW_CONTROLLER_NIB_NAME
        ];
    }

    return applicationSpecificPreferencesWindowControllerSingletonInstance;
}

/******************************************************************************\
 * -initWithWindowNibName:
 *
 * Initialise the class, internally recording (and indeed creating, if need be)
 * an icon style manager and associated data in passing.
 *
 * Do not manually "alloc" an instance of this controller and then call here.
 * Instead, always use "+applicationSpecificPreferencesWindowController".
 *
 * In:  ( NSString * ) windowNibName
 *      Name of the NIB containing this controller's window.
 *
 * Out: ( id )
 *      This instance ("self").
\******************************************************************************/

- ( instancetype ) initWithWindowNibName: ( NSString * ) windowNibName
{
    if ( ( self = [ super initWithWindowNibName: windowNibName ] ) )
    {
        iconStyleManager     = [ IconStyleManager iconStyleManager     ];
        managedObjectContext = [ iconStyleManager managedObjectContext ];
        managedObjectModel   = [ iconStyleManager managedObjectModel   ];

        /* If an Icon Style is deleted we need to know about it, as the
         * preferences might have specified that style as a default value.
         */

        [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                    selector: @selector( iconStyleListChanged: )
                                                        name: NSManagedObjectContextObjectsDidChangeNotification
                                                      object: managedObjectContext ];
    }

    return self;
}

/******************************************************************************\
 * -initToolbar
 *
 * Override GenericPreferencesWindowController's "-initToolbar" method; add the
 * toolbar entries specific to this application's Preferences dialogue box.
\******************************************************************************/

- ( void ) initToolbar
{
    [ self addView: generalPreferencesView label: @"General" image: [ NSImage imageNamed: @"NSPreferencesGeneral" ] ];

//TODO: Version 2.1.
//    NSString * finderPath = [ [ NSWorkspace sharedWorkspace ] fullPathForApplication: @"Finder" ];
//    NSImage  * finderIcon = [ [ NSWorkspace sharedWorkspace ] iconForFile: finderPath ];
//
//    [ self addView: integrationPreferencesView label: @"Integration" image: [ NSImage imageNamed: @"NSComputer" ] ];
//    [ self addView: finderPreferencesView      label: @"Finder"      image: finderIcon                            ];

    #ifdef UPDATABLE
        Add_Folder_IconsAppDelegate * delegate     = [ NSApp delegate ];
        UpdateHelper                * updateHelper = [ delegate updateHelper ];

        if ( updateHelper != nil )
        {
            NSBundle * thisAppBundle   = [ NSBundle mainBundle ];
            NSString * sparkleIconPath = [ thisAppBundle pathForResource: @"Sparkle" ofType: @"icns" ];
            NSImage  * sparkleIcon     = [ [ NSImage alloc ] initWithContentsOfFile: sparkleIconPath ];

            [ updatesPreferencesView addSubview: [ updateHelper view ] ];
            [ self addView: updatesPreferencesView label: @"Updates" image: sparkleIcon ];
        }
    #endif

    [ self addView: advancedPreferencesView label: @"Advanced" image: [ NSImage imageNamed: @"NSAdvanced" ] ];
}

/******************************************************************************\
 * -iconStyleListChanged:
 *
 * Called from the default NSNotificationCenter when the IconStyle collection
 * managed by CoreData changes.
 *
 * The method checks to see if all the styles used in the current list of
 * folders are defined. If any are deleted, a default style is used instead.
 *
 * In: ( NSNotification * ) notification
 *     The notification details.
\******************************************************************************/

- ( void ) iconStyleListChanged: ( NSNotification * ) notification
{
    NSDictionary * userInfo      = [ notification userInfo ];
    NSSet        * deletedStyles = userInfo[ NSDeletedObjectsKey ];

    if ( [ deletedStyles count ] == 0 ) return;

    /* Find the user's default style. The method ensures a valid style is
     * always returned, so it copes with deletions. Reset the configured
     * value; it'll either be unchanged, or was deleted and had to be changed.
     */

    IconStyle * defaultStyle = [ iconStyleManager findDefaultIconStyle ];

    /* Turn the object a string suitable for storing in the preferences */

    CoreDataObjectIDTransformer * vt = ( CoreDataObjectIDTransformer * )
    [
        NSValueTransformer valueTransformerForName: CORE_DATA_OBJECT_ID_TRANSFORMER_NAME
    ];

    NSString * objStr = [ vt reverseTransformedValue: [ defaultStyle objectID ] ];

    NSUserDefaults * userDefaults = [ NSUserDefaults standardUserDefaults ];
    [ userDefaults setValue: objStr forKey: PREFERENCES_DEFAULT_STYLE_KEY ];
}

@end
