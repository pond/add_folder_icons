//
//  MainWindowController.h
//
//  Created by Andrew Hodgkinson on 28/03/2010.
//  Copyright 2010, 2011 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IconStyleArrayController.h"
#import "IconStyleManager.h"
#import "FolderProcessNotificationProtocol.h"

@interface MainWindowController : NSWindowController < NSTableViewDataSource,
                                                       NSMenuDelegate,
                                                       FolderProcessNotification >
{
    /* Outlet members */

    IBOutlet NSButton                 * startButton;
    IBOutlet NSButton                 * clearButton;
    IBOutlet NSButton                 * addButton;
    IBOutlet NSButton                 * removeButton;
    IBOutlet NSPopUpButton            * popUpButton;
    IBOutlet NSTableView              * folderList;
    IBOutlet NSTableColumn            * folderListStyleColumn;
    IBOutlet NSProgressIndicator      * spinner;
    IBOutlet NSTextField              * spinnerLabel;

    IBOutlet IconStyleArrayController * stylesArrayController;
    IBOutlet NSMenuItem               * stylesSubMenuItem;
    IBOutlet NSMenu                   * stylesSubMenu;

    IBOutlet NSPanel                  * progressIndicatorPanel;
    IBOutlet NSTextField              * progressIndicatorLabel;
    IBOutlet NSProgressIndicator      * progressIndicator;
    IBOutlet NSButton                 * progressStopButton;

    /* Dynamically created items */

    NSOpenPanel                       * openPanel;
    NSMutableArray                    * tableContents;
    NSThread                          * workerThread;

    /* An icon style manager instance must be supplied by the instantiator.
     * It is used to look up CoreData information for the central icon style
     * collection. This is needed by things like bindings.
     */

    IconStyleManager                  * iconStyleManager;
    NSManagedObjectContext            * managedObjectContext;
    NSManagedObjectModel              * managedObjectModel;
}

@property (            retain, readonly ) IconStyleManager       * iconStyleManager;
@property ( nonatomic, retain, readonly ) NSManagedObjectContext * managedObjectContext;
@property ( nonatomic, retain, readonly ) NSManagedObjectModel   * managedObjectModel;

/* Actions */

- ( IBAction ) closeProgressPanel:     ( id           ) sender;
- ( IBAction ) addButtonPressed:       ( id           ) sender;
- ( IBAction ) removeButtonPressed:    ( id           ) sender;
- ( IBAction ) styleSubmenuItemChosen: ( NSMenuItem * ) sender; /* Must be an NSMenuItem */
- ( IBAction ) startButtonPressed:     ( id           ) sender;
- ( IBAction ) clearButtonPressed:     ( id           ) sender;

/* Initialisation methods */

- ( void ) initOpenPanel;
- ( void ) initWindowContents;

/* Inter-process communication */

- ( void ) doCommsThread;

/* Modal progress panel and related tasks */

- ( void ) showProgressPanelWithMessage: ( NSString * ) message
                              andAction: ( SEL        ) actionSelector
                                andData: ( id         ) actionSelectorData;

- ( void ) considerInsertingSubfoldersOf: ( NSDictionary * ) parentFolders;
- ( void ) insertSubfoldersOnTimer:       ( NSTimer      * ) theTimer;
- ( void ) addSubFoldersOf:               ( NSDictionary * ) parentFolders;

- ( void ) createFolderIcons:             ( NSArray      * ) constArrayOfDictionaries;
- ( void ) advanceProgressBarFor:         ( NSString     * ) fullPOSIXPath;
- ( void ) considerEmptyingFolderList;

/* Folder list and related table view management */

- ( void )                addFolder: ( NSString     * ) path;

- ( void )                addFolder: ( NSString     * ) path
                          withStyle: ( IconStyle    * ) style;

- ( void )             insertFolder: ( NSString     * ) path
                            atIndex: ( NSUInteger     ) index;

- ( void )             insertFolder: ( NSString     * ) path
                            atIndex: ( NSUInteger     ) index
                          withStyle: ( IconStyle    * ) style;

- ( void ) insertFolderByDictionary: ( NSDictionary * ) dictionary;

- ( NSIndexSet * ) removeDuplicatesFromIndices: ( NSIndexSet * ) sourceBlock
                               comparedAgainst: ( NSIndexSet * ) matchBlock;

- ( void ) folderListSelectionChanged: ( NSNotificationCenter * ) center;

/* Styles sub-menu and general style management */

- ( void ) iconStyleListChanged: ( NSNotificationCenter * ) center;

@end
