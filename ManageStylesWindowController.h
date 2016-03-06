//
//  ManageStylesWindowController.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 14/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IconStyleArrayController.h"
#import "IconStyleManager.h"
#import "DSClickableURLTextField.h"

@interface ManageStylesWindowController : NSWindowController
{
    IBOutlet IconStyleArrayController * stylesArrayController;

    IBOutlet NSButton                 * addStyleButton;

    IBOutlet NSPanel                  * editStylePanel;
    IBOutlet NSPopUpButton            * editStyleMethodPopup;
    IBOutlet NSImageView              * editStyleNoSlipCoverIcon;
    IBOutlet DSClickableURLTextField  * editStyleNoSlipCoverLabel;
    IBOutlet NSButton                 * editStyleCancelButton;
    IBOutlet NSButton                 * editStyleSaveButton;
    IBOutlet NSImageView              * editStylePreview;

    /* An array of last-known-good case name strings is kept internally
     * and managed by an NSArrayController instance in casesArrayController
     * so that we can simply use bindings in Interface Builder to generate
     * a pop-up menu of case names.
     */

    IBOutlet NSArrayController        * casesArrayController;

    /* An icon style manager instance must be supplied by the instantiator.
     * It is used to look up CoreData information for the central icon style
     * collection. This is needed by things like bindings.
     */

    IconStyleManager                  * iconStyleManager;
    NSManagedObjectContext            * managedObjectContext;
    NSManagedObjectModel              * managedObjectModel;

    /* Cached array of key paths used for observing style changes during
     * editing and a ached folder image reference used for icon style
     * previews generated as a result of changes in the observed keys.
     */

    NSArray                           * styleObservableKeyPaths;
    CGImageRef                          cachedFolderImage;
}

@property ( strong, readonly ) IconStyleManager       * iconStyleManager;
@property ( strong, readonly ) NSManagedObjectContext * managedObjectContext;
@property ( strong, readonly ) NSManagedObjectModel   * managedObjectModel;

/* Actions */

- ( IBAction ) showEditStyle:  ( id ) sender;
- ( IBAction ) closeEditStyle: ( id ) sender;

@end
