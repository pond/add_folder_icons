//
//  ManageStylesWindowController.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 14/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "ManageStylesWindowController.h"
#import "SlipCoverSupport.h"
#import "IconStyleManager.h"
#import "Icons.h"
#import "IconGenerator.h"

@implementation ManageStylesWindowController

@synthesize iconStyleManager,
            managedObjectContext,
            managedObjectModel;

/******************************************************************************\
 * -awakeFromNib
 *
 * The label shown in the 'edit style' sheet when SlipCover is not available
 * includes some static text and a clickable link that takes the user to the
 * SlipCover web site. This requires a surprisingly large amount of code and a
 * supporting custom class (see 'DSClickableURLTextField') to do effectively,
 * including showing the 'right kind' of mouse pointer when hovering over the
 * link text.
 *
 * Since this level of configuration cannot be achieved in Interface Builder it
 * must be done programatically. That's all we do in this method.
\******************************************************************************/

- ( void ) awakeFromNib
{
    /* Attributes for a link to the SlipCover web site */

    NSString     * url     = NSLocalizedString( @"http://www.macupdate.com/app/mac/31676/slipcover", @"SlipCover web site URL" );
    NSNumber     * uFlags  = [ NSNumber numberWithUnsignedInteger: NSUnderlinePatternSolid | NSUnderlineStyleSingle ];
    NSDictionary * attrs   =
    [
        NSDictionary dictionaryWithObjectsAndKeys:
            url,                   NSLinkAttributeName,
            [ NSColor blueColor ], NSForegroundColorAttributeName,
            uFlags,                NSUnderlineStyleAttributeName,
            nil
    ];

    /* Attributed link text */

    NSString           * isLink  = NSLocalizedString( @"Is it installed?", @"Second part of message shown when SlipCover cannot be found. Turned into a link to the SlipCover web site." );
    NSAttributedString * isLinkStr =
    [
            [ NSAttributedString alloc ] initWithString: isLink
                                             attributes: attrs
        ];

    /* Start the overall string with the non-link text */

    NSString                  * nonLink    = NSLocalizedString( @"Cannot find cases for SlipCover. ", @"First part of message shown when SlipCover can't be found, including a trailing space. This is kept as plain text." );
    NSMutableAttributedString * overallStr =
    [
            [ NSMutableAttributedString alloc ] initWithString: nonLink
        ];

    /* Finally append the link text. Cocoa is a funny beast really. Some things
     * are so easy; complex dialogue boxes bound via Core Data to database
     * back-ends with almost no code. Yet some things, like displaying a URL
     * in a user interface, require large amounts of the stuff!
     */
    
    [ overallStr appendAttributedString: isLinkStr ];

    [ editStyleNoSlipCoverLabel setCanCopyURLs:           YES ];
    [ editStyleNoSlipCoverLabel setAttributedStringValue: overallStr ];
}

/******************************************************************************\
 * -initWithWindowNibName:
 *
 * Initialise the class, internally recording (and indeed creating, if need be)
 * an icon style manager and associated data in passing.
 *
 * Upon initialisation, this controller will call 'center' on its window to
 * set its initial position, but does not open that window.
 *
 * In:  ( NSString * ) windowNibName
 *      Name of the NIB containing this controller's window.
 *
 * Out: ( id )
 *      This instance ("self").
\******************************************************************************/

- ( id ) initWithWindowNibName: ( NSString * ) windowNibName
{
    if ( ( self = [ super initWithWindowNibName: windowNibName ] ) )
    {
        iconStyleManager     = [ IconStyleManager iconStyleManager     ];
        managedObjectContext = [ iconStyleManager managedObjectContext ];
        managedObjectModel   = [ iconStyleManager managedObjectModel   ];

        [ [ self window ] center ];

        /* Cache an array of the key paths that we observe on a temporary
         * item edited in the Edit Style panel so that the preview image
         * can be updated as the user makes changes. Cache the folder image
         * used by the preview generator too.
         */

        styleObservableKeyPaths =
        [
                NSArray arrayWithObjects: @"usesSlipCover",
                                          @"slipCoverName",
                                          @"cropToSquare",
                                          @"whiteBackground",
                                          @"dropShadow",
                                          @"randomRotation",
                                          @"onlyUseCoverArt",
                                          @"maxImages",
                                          @"showFolderInBackground",
                                          nil
            ];

        cachedFolderImage = allocFolderIcon();
    }

    return self;
}

- ( void ) dealloc
{
    CFRelease( cachedFolderImage );
}

/******************************************************************************\
 * -showEditStyle:
 *
 * Show the Edit Style sheet IN A MODAL LOOP. On exit, the application will
 * be locked into a modal event cycle until the sheet closes. This should be
 * achieved by invoking action "-closeEditStyle:".
 *
 * The edit sheet can be invoked to edit a default parameter newly added style
 * or to edit an existing style based on the input parameter 'sender'. See the
 * parameter list details for more. The sheet MUST NOT be shown for edit-like
 * operation if either no style is selected, or multiple styles are selected.
 * results will be undefined in such cases. If showing for add-like operation,
 * any previous selection in the Manage Styles table will be discarded and the
 * new item will be selected on exit if it was added, or no item will be
 * selected if the sheet was cancelled.
 *
 * In:       ( id ) sender
 *           Message sender. If this is the addStyleButton then the dialogue
 *           box is opened in order to add a new style, else it is opened in
 *           order to edit the style selected in the Manage Styles window's
 *           table view.
 *
 * See also: -closeEditStyle:
\******************************************************************************/

- ( IBAction ) showEditStyle: ( id ) sender
{
    /* Reset the array being handled by the controller used to create the menu
     * of SlipCover case names by bindings. The controller will observe the
     * array change and update itself and in turn the menu will be updated too.
     * We do this reset as the contents of the array could change whenever the
     * main thread's run loop is active due to IconStyleManager's observeration
     * of the folders containing case definitions.
     */

    NSMutableArray * caseDefinitions = [ iconStyleManager slipCoverDefinitions ];

    if ( [ caseDefinitions count ] == 0 )
    {
        /* No SlipCover! Disable the "Uses SlipCover" / "Custom settings" menu
         * and show the "No SlipCover" warning.
         */

        [ editStyleMethodPopup      setEnabled: NO ];
        [ editStyleNoSlipCoverIcon  setHidden:  NO ];
        [ editStyleNoSlipCoverLabel setHidden:  NO ];
    }
    else
    {
        /* We really want only unique case names, but the collection operator
         * to achieve that ('@distinctUnionOfObjects') changes the order of
         * the returned items which can cause odd effects (e.g. the default
         * item selected for new styles is not necessarily the first menu
         * entry, which looks rather arbitrary to the user). In any event,
         * using the "non-distinct" operator is a bit faster, though it's not
         * as if it matters that much in this particular piece of code.
         */

        NSArray    * caseNames    = [ caseDefinitions valueForKeyPath: @"@unionOfObjects.name" ]; /* http://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueCoding/Concepts/ArrayOperators.html#//apple_ref/doc/uid/20002176-SW5 */
        NSUInteger   oldNameCount = [ [ casesArrayController arrangedObjects ] count ];
        NSIndexSet * oldIndexes   = [ NSIndexSet indexSetWithIndexesInRange: NSMakeRange( 0, oldNameCount ) ];

        if ( oldNameCount > 0 ) [ casesArrayController removeObjectsAtArrangedObjectIndexes: oldIndexes ];
        [ casesArrayController addObjects: caseNames ];

        /* Enable the "Uses SlipCover" / "Custom settings" menu and hide the
         * "No SlipCover" warning.
         */

        [ editStyleMethodPopup      setEnabled: YES ];
        [ editStyleNoSlipCoverIcon  setHidden:  YES ];
        [ editStyleNoSlipCoverLabel setHidden:  YES ];
    }

    /* Whether editing an existing item or adding a new one, a new undo group
     * is required so that the user can cancel their changes if they wish.
     */

    NSManagedObjectContext * moc = managedObjectContext; /* For brevity */
    [ [ moc undoManager ] beginUndoGrouping ]; /* See also "closeEditStyle:" */

    if ( sender == addStyleButton )
    {
        /* Create a "blank" style, inserted into the managed object context. 
         * Make sure the runtime knows about it without necessarily persisting
         * the changes to disc; right now, the new object is intentionally
         * entirely temporary (see also "closeEditStyle:").
         */

        IconStyle * newStyle = [ iconStyleManager insertBlankUserStyleAndProcessChanges ];
        [ stylesArrayController fetch: nil ];
        [ stylesArrayController setSelectedObjects: [ NSArray arrayWithObject: newStyle ] ];
        
        /* Drop through to the code which opens the editor sheet - it's the
         * same now, whether editing a previously selected item, or editing
         * the new, just-selected item from above.
         */
    }

    /* Attach observers to the currently selected object so that the preview
     * image can be updated as the user modifies parameters. These are removed
     * again in the '-closeEditStyle:' action prior to e.g. an undo action
     * firing (since that breaks the preview, as the temporary edited style
     * would be 'already gone' by the time the observer was invoked).
     */

    IconStyle * editedStyle = [ [ stylesArrayController selectedObjects ] objectAtIndex: 0 ];
    for ( NSString * keyPath in styleObservableKeyPaths )
    {
        [ editedStyle addObserver: self forKeyPath: keyPath options: 0 context: NULL ];
    }

    /* ...and make sure the preview image is initially up to date */

    [ self observeValueForKeyPath: nil
                         ofObject: editedStyle
                           change: nil
                          context: nil ];

    /* Now start the modal session */

    [ NSApp beginSheet: editStylePanel
        modalForWindow: [ self window ]
         modalDelegate: nil   
        didEndSelector: nil   
           contextInfo: nil ];

    [ NSApp runModalForWindow: editStylePanel ];
    [ NSApp          endSheet: editStylePanel ];

    [ editStylePanel orderOut: self ];
}

/******************************************************************************\
 * -closeEditStyle:
 *
 * Close the Edit Style sheet, exiting the modal event loop entered by a
 * prior call to "-showEditStyle:". This prior call must always be made before
 * calling here to close the sheet. If this action is invoked outside of such
 * a context, behaviour is undefined.
 *
 * In:       ( id ) sender
 *           Message sender. The changes made in the editing sheet will be
 *           discarded if the sender is "editStyleCancelButton", else saved.
 *
 * See also: -showEditStyle:
\******************************************************************************/

- ( IBAction ) closeEditStyle: ( id ) sender
{
    /* First, remove all observers for the preview image as any further
     * changes to the edited style are either not interesting or are
     * destructive ('Cancel' -> Undo -> object is deleted).
     */

    IconStyle * editedStyle = [ [ stylesArrayController selectedObjects ] objectAtIndex: 0 ];
    for ( NSString * keyPath in styleObservableKeyPaths )
    {
        [ editedStyle removeObserver: self forKeyPath: keyPath ];
    }

    NSManagedObjectContext * moc = managedObjectContext; /* For brevity */
    [ [ moc undoManager ] endUndoGrouping ]; /* See also "showEditStyle:" */

    /* We might think that issuing 'undo' before closing the modal sheet, in
     * the 'cancel' case, may stop the temporary-and-now-deleted style from
     * showing up in the 'Manage Styles' table because the editing sheet
     * obscures it. In practice, that's really up to however Mac OS orders
     * actually dealing with the queue of changes including closing the sheet
     * and updating the styles table via bindings. At the time of writing,
     * you actually always see the sheet close before the table updates so
     * it's a bit ugly - briefly, you see the about-to-vanish style. Anyway,
     * AFAICT that's unavoidable with the create-edit-cancel-undor approach
     * taken here.
     *
     * Bottom line: Get out of the modal loop first before cancellation or
     * saving, so that any errors arising can be properly dealt with. How
     * well the GUI behaves is up to Mac OS.
     *
     * TODO: Usually there are many ways to skin a cat in Cocoa. Is there a
     * TODO: more elegant/recommended approach for editing temporary objects
     * TODO: with CoreData bindings?
     */

    [ NSApp stopModal ];

    if ( sender == editStyleCancelButton )
    {
        [ [ moc undoManager ] undo ];
    }
    else
    {
        NSError * error = nil;
        if ( ! [ moc save: &error ] ) [ NSApp presentError: error ];
    }
}

/******************************************************************************\
 * -observeValueForKeyPath:ofObject:change:context:
 *
 * NSKeyValueObserving: In response to an (assumed) change in an IconStyle
 * which is being edited, update the preview image shown in the Edit Style
 * panel.
 *
 * This method only needs its second parameter, 'editedStyle', to be valid. It
 * can be called outside the notification mechanism if a caller wants to force
 * a preview update. Just set other parameters to 'nil'.
 *
 * In: ( NSString * ) keyPath
 *     The key path which has changed (ignored);
 *
 *     ( IconStyle * ) editedStyle
 *     The style which is being edited - this style is used to generate the
 *     updated preview;
 *
 *     ( NSDictionary * ) change
 *     Change information (ignored);
 *
 *     ( void * ) context
 *     Context information (ignored).
\******************************************************************************/

- ( void ) observeValueForKeyPath: ( NSString     * ) keyPath
                         ofObject: ( IconStyle    * ) editedStyle
                           change: ( NSDictionary * ) change
                          context: ( void         * ) context
{
    ( void ) keyPath;
    ( void ) change;
    ( void ) context;

    /* A special folder in the application resources contains four images,
     * three general and one with the name "cover.jpg" as a cover art example.
     * There are no subdirectories. It is used as a source for the icon
     * generator to create previews.
     *
     * Before a preview can be built, we need to map an IconStyle to an
     * IconParameters structure.
     */

    IconParameters * params = [ [ IconParameters alloc ] init ];

    params.commsChannel           = nil;
    params.previewMode            = YES;

    params.crop                   = [ [ editedStyle cropToSquare           ] boolValue        ];
    params.border                 = [ [ editedStyle whiteBackground        ] boolValue        ];
    params.shadow                 = [ [ editedStyle dropShadow             ] boolValue        ];
    params.rotate                 = [ [ editedStyle randomRotation         ] boolValue        ];
    params.singleImageMode        = [ [ editedStyle onlyUseCoverArt        ] boolValue        ];
    params.maxImages              = [ [ editedStyle maxImages              ] unsignedIntValue ];
    params.showFolderInBackground = [ [ editedStyle showFolderInBackground ] unsignedIntValue ];
    params.coverArtNames          = [ NSMutableArray arrayWithObject: @"cover" ];

    /* Do we need to find the SlipCover case definition? */

    if ( [ [ editedStyle usesSlipCover ] boolValue ] == YES )
    {
        params.slipCoverCase =
        [
            SlipCoverSupport findDefinitionFromName: [ editedStyle slipCoverName ]
                                  withinDefinitions: [ iconStyleManager slipCoverDefinitions ]
        ];
    }
    else
    {
        params.slipCoverCase = nil;
    }

    /* Now make the preview image */

    [ NSGraphicsContext saveGraphicsState ];

    NSImage    * preview  = nil;
    OSStatus     status   = noErr;
    CGImageRef   imageRef = allocIconForFolder
    (
        [ [ [ NSBundle mainBundle ] resourcePath ] stringByAppendingPathComponent: @"Preview" ],
        NO,  /* Opaque (no, this isn't for QuickLook) */
        YES, /* Skip package-like folders */
        cachedFolderImage,
        & status,
        params
    );

    if ( imageRef != NULL ) preview = [ [ NSImage alloc ] initWithCGImage: imageRef size: NSZeroSize ];

    [ NSGraphicsContext restoreGraphicsState ];

    /* If that all worked, update the view */

    if ( preview != nil )
    {
        [ editStylePreview setImage: preview ];
    }
    
    if ( imageRef != nil ) CFRelease( imageRef );
}

@end
