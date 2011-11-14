//
//  ApplicationSpecificPreferencesWindowController.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 13/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "GenericPreferencesWindowController.h"
#import "IconStyleManager.h"

@interface ApplicationSpecificPreferencesWindowController : GenericPreferencesWindowController
{
    IBOutlet NSView        * generalPreferencesView;
    IBOutlet NSView        * integrationPreferencesView;
    IBOutlet NSView        * finderPreferencesView;
    IBOutlet NSView        * updatesPreferencesView;
    IBOutlet NSView        * advancedPreferencesView;

    /* An icon style manager instance must be supplied by the instantiator.
     * It is used to look up CoreData information for the central icon style
     * collection. This is needed by things like bindings.
     */

    IconStyleManager       * iconStyleManager;
    NSManagedObjectContext * managedObjectContext;
    NSManagedObjectModel   * managedObjectModel;
}

@property (            retain, readonly ) IconStyleManager       * iconStyleManager;
@property ( nonatomic, retain, readonly ) NSManagedObjectContext * managedObjectContext;
@property ( nonatomic, retain, readonly ) NSManagedObjectModel   * managedObjectModel;

/* Allocation and initialisation */

+ ( ApplicationSpecificPreferencesWindowController * ) applicationSpecificPreferencesWindowController;

/* Listening for changes that may change the settings */

- ( void ) iconStyleListChanged: ( NSNotification * ) notification;

@end
