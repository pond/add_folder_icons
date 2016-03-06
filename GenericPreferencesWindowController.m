//
//  GenericPreferencesWindowController.m
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

#import "GenericPreferencesWindowController.h"

@implementation GenericPreferencesWindowController

/******************************************************************************\
 * +allocPreferencesWindowController
 *
 * Obtain a pointer to the preferences controller.
 *
 * Out: ( id )
 *      Pointer to a singleton instance of the preferences controller. Callers
 *      should cast this to the appropriate subclass pointer type (e.g.
 *      "MySubclassPreferencesController *"). The object is never released
 *      after allocation.
\******************************************************************************/

static id preferencesWindowControllerSingletonInstance = nil;

+ ( id ) allocPreferencesWindowController
{
    if ( preferencesWindowControllerSingletonInstance == nil )
    {
        preferencesWindowControllerSingletonInstance = [
            [ self alloc ] initWithWindowNibName: GENERIC_PREFERENCES_WINDOW_CONTROLLER_NIB_NAME
        ];
    }

    return preferencesWindowControllerSingletonInstance;
}

/******************************************************************************\
 * -addView:label:
 *
 * Add a given subview to the preferences window using the given identifying
 * label. An image with the same name as the label will be used in the toolbar.
 *
 * In:       ( NSView * )
 *           Subview to add, read from the "Preferences" NIB;
 *    
 *           ( NSString * )
 *           Unique label for this subview. An NSImage of the same name must
 *           exist and will be used in the toolbar.
 *
 * See also: -initToolbar
 *           -addView:label:image:
\******************************************************************************/

- ( void ) addView: ( NSView * ) view label: ( NSString * ) label
{
    [ self addView: view
             label: label
             image: [ NSImage imageNamed: label ] ];
}

/******************************************************************************\
 * -addView:label:image:
 *
 * Add a given subview to the preferences window using the given identifying
 * label and given image for the toolbar.
 *
 * In:       ( NSView * )
 *           Subview to add, read from the "Preferences" NIB;
 *     
 *           ( NSString * )
 *           Unique label for this subview;
 *     
 *           ( NSImage * )
 *           Image to use in the toolbar.
 *
 * See also: -initToolbar
 *           -addView:label:
 \******************************************************************************/

- ( void ) addView: ( NSView * ) view label: ( NSString * ) label image: ( NSImage * ) image
{
    NSString      * labelCopy = [ label copy ];
    NSToolbarItem * item      =
    [
            [ NSToolbarItem alloc ] initWithItemIdentifier: labelCopy
        ];

    [ item setLabel:  label                       ];
    [ item setImage:  image                       ];
    [ item setTarget: self                        ];
    [ item setAction: @selector( setActiveView: ) ];
    
    [ toolbarLabels addObject: labelCopy ];

    toolbarViews[ labelCopy ] = view;
    toolbarItems[ labelCopy ] = item;
}

/******************************************************************************\
 * -initToolbar
 *
 * Does nothing. Subclasses must implement this and add views by calling
 * "-addView:label:" or "-addView:label:image:".
\******************************************************************************/

- ( void ) initToolbar
{
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark NSWindowController overrides
//------------------------------------------------------------------------------

/******************************************************************************\
 * -initWithWindow:
 *
 * NSWindowController: Initialise the preferences window.
 *
 * In:  ( NSWindow * ) window
 *      Window to initialise.
 *
 * Out: ( id )
 *      Initialised 'self'.
\******************************************************************************/

- ( instancetype ) initWithWindow: ( NSWindow * ) window
{
    self = [ super initWithWindow: window ];

    if ( self != nil )
    {
        toolbarLabels = [ [ NSMutableArray      alloc ] init ];
        toolbarViews  = [ [ NSMutableDictionary alloc ] init ];
        toolbarItems  = [ [ NSMutableDictionary alloc ] init ];
    }
    
    return self;
}

/******************************************************************************\
 * -windowDidLoad
 *
 * NSWindowController: Called when the window definition has been loaded. Used
 * to create an instance of the window and set up preference tab subviews.
\******************************************************************************/

- ( void ) windowDidLoad
{
    NSWindow * window =
    [
            /* Size must be "big", to avoid cropping subviews. According to the
             * documentation, the window server limits sizes to 10000 itself,
             * so that's a good value. This is just an initial setting anyway;
             * the subviews are yield the final visible size.
             */
        
            [ NSWindow alloc ] initWithContentRect: NSMakeRect( 0, 0, 10000, 10000 )
                                         styleMask: (
                                                        NSTitledWindowMask |
                                                        NSClosableWindowMask |
                                                        NSMiniaturizableWindowMask
                                                    )
                                           backing: NSBackingStoreBuffered
                                             defer: YES
        ];
    
    /* With the call below, the parent creates its own copy of the window and
     * assumes ownership. Thereafter, we can make no assumptions about the
     * lifecycle of this object so each time we refer to it, we must re-call
     * "[ self window ]" in case the object has changed during the execution
     * of this code (via another thread).
     */

    [ self setWindow: window ];
    [ [ self window ] setShowsToolbarButton: NO ];
    
    /* Create a subview matching the parent window's content's frame size */  

    subview =
    [
            [ NSView alloc ] initWithFrame: [ [ [ self window ] contentView ] frame ]
        ];

    [ subview setAutoresizingMask: ( NSViewMinYMargin | NSViewWidthSizable ) ];
    [ [ [ self window ] contentView ] addSubview: subview ];
}

/******************************************************************************\
 * -showWindow:
 *
 * NSWindowController: Show the window being managed by this controller.
 *
 * In: ( id )
 *     The control sending this message (may be 'nil').
\******************************************************************************/

- ( void ) showWindow: ( id ) sender
{
    /* Set up the toolbar and view state if not done already */

    if ( [ [ self window ] toolbar ] == nil )
    {
        [ self initToolbar ];
        
        NSToolbar * toolbar =
        [
            [ NSToolbar alloc ] initWithIdentifier: GENERIC_PREFERENCES_WINDOW_CONTROLLER_TOOLBAR_IDENTIFIER
        ];
        
        [ toolbar setAllowsUserCustomization: NO                               ];
        [ toolbar setAutosavesConfiguration:  NO                               ];
        [ toolbar setSizeMode:                NSToolbarSizeModeDefault         ];
        [ toolbar setDisplayMode:             NSToolbarDisplayModeIconAndLabel ];
        [ toolbar setDelegate:                self                             ];

        [ [ self window ] setToolbar: toolbar ];
    
        /* Select the first tab */
        
        NSString * firstLabel = toolbarLabels[ 0 ];
        [ [ [ self window ] toolbar ] setSelectedItemIdentifier: firstLabel ];
        [ self displayViewForLabel: firstLabel animate: NO ];
    }

    /* Finally, position and show the window */

    [ [ self window ] center ];
    [ super showWindow: sender ]; 
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Implement NSToolbarDelegate
//------------------------------------------------------------------------------

/******************************************************************************\
 * -toolbarDefaultItemIdentifiers:
 *
 * NSToolbarDelegate: Return the default unique identifiers for the toolbar.
 *
 * In:  ( NSToolbar * ) toolbar
 *      Toolbar of interest (ignored; we only handle one).
 *
 * Out: ( NSArray * )
 *      Array of identifying strings.
\******************************************************************************/

- ( NSArray * ) toolbarDefaultItemIdentifiers: ( NSToolbar * ) toolbar
{
    ( void ) toolbar;
    return toolbarLabels;
}

/******************************************************************************\
 * -toolbarAllowedItemIdentifiers:
 *
 * NSToolbarDelegate: Return the unique identifiers of items allowed to be
 * shown in the toolbar - in our case, all of them, always.
 *
 * In:  ( NSToolbar * ) toolbar
 *      Toolbar of interest (ignored; we only handle one).
 *
 * Out: ( NSArray * )
 *      Array of identifying strings.
\******************************************************************************/

- ( NSArray * ) toolbarAllowedItemIdentifiers: ( NSToolbar * ) toolbar 
{
    ( void ) toolbar;
    return toolbarLabels;
}

/******************************************************************************\
 * -toolbarSelectableItemIdentifiers:
 *
 * NSToolbarDelegate: Return the unique identifiers of items allowed to be
 * selected in the toolbar - in our case, all of them, always.
 *
 * In:  ( NSToolbar * ) toolbar
 *      Toolbar of interest (ignored; we only handle one).
 *
 * Out: ( NSArray * )
 *      Array of identifying strings.
\******************************************************************************/

- ( NSArray * ) toolbarSelectableItemIdentifiers: ( NSToolbar * ) toolbar 
{
    ( void ) toolbar;
    return toolbarLabels;
}

/******************************************************************************\
 * -toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
 *
 * NSToolbarDelegate: Return a toolbar item of the kind indicated by the given
 * unique identifier, to be used in the given toolbar.
 *
 * In:  ( NSToolbar * ) toolbar
 *      Toolbar of interest (ignored; we only handle one);
 *
 *      ( NSString * ) identifier
 *      Unique item identifier;
 *
 *      ( BOOL ) willBeInserted
 *      Used for toolbar customisation - ignored as we don't allow the
 *      preferences toolbar to be customised.
 *
 * Out: ( NSToolbarItem * )
 *      The requested item.
\******************************************************************************/

- ( NSToolbarItem * ) toolbar: ( NSToolbar * ) toolbar itemForItemIdentifier: ( NSString * ) identifier willBeInsertedIntoToolbar: ( BOOL ) willBeInserted 
{
    ( void ) toolbar;
    ( void ) willBeInserted;
    
    return toolbarItems[ identifier ];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Subview selection and display
//------------------------------------------------------------------------------

/******************************************************************************\
 * -setActiveView:
 *
 * Set the currently active subview ('tab').
 * 
 * In:       ( NSToolbarItem * ) toolbarItem
 *           Toolbar item corresponding to subview to be shown.
 *
 * See also: -addView:label:image:
\******************************************************************************/

- ( void ) setActiveView: ( NSToolbarItem * ) toolbarItem
{
	[ self displayViewForLabel: [ toolbarItem itemIdentifier ] animate: YES ];
}

/******************************************************************************\
 * -displayViewForLabel:animate:
 *
 * Change the window so that it shows the tab identified by the given unique
 * label, optionally animating any change in window size.
 * 
 * In:       ( NSString * ) label
 *           Label of tab to show;
 *
 *           ( BOOL ) animate
 *           YES to animate the transtion, else NO.
 *
 * See also: -showWindow:
 *           -setActiveView:
\******************************************************************************/

- ( void ) displayViewForLabel: ( NSString * ) label animate: ( BOOL ) animate
{	
	NSView * oldView = nil;
	NSView * newView = toolbarViews[ label ];

    /* Find the last subview. We only ever expect one, but take the last in
     * the list just in case there are several (though we'd be in a fairly
     * unexpected and rather broken state then anyway).
     */

	if ( [ [ subview subviews ] count ] > 0 )
    {
		NSEnumerator * subviewsEnum = [ [ subview subviews ] reverseObjectEnumerator ];
		oldView = [ subviewsEnum nextObject ];
    }

    /* Has there been a change? */
	
	if ( ! [ newView isEqualTo: oldView ] )
    {
        /* Calculate the height difference between the current content subview
         * and the requested new subview and use this to create a frame which
         * matches the new subview bounding box, but has an offset y coordinate
         * so that the subview top edge is at the top of the visible area. As
         * the parent window's size is changed from one subview to the next,
         * a gap below the new subview will be closed up (if the new is shorter
         * than the old) else the new subview will be revealed as the bottom
         * edge moves downwards (if the new is taller than the old).
         */
   
		NSRect frame = [ newView bounds ];
		frame.origin.y = NSHeight( [ subview frame ] ) - NSHeight( [ newView bounds ] );

		[ newView setFrame:   frame   ];
		[ subview addSubview: newView ];

		[ [ self window ] setInitialFirstResponder: newView ];
		[ oldView removeFromSuperviewWithoutNeedingDisplay ];
		[ newView setHidden: NO ];
        
        [ [ self window ] setFrame: [ self frameForView: newView ]
                           display: YES
                           animate: animate ];

        /* Make sure the window title is updated too */

		[ [ self window ] setTitle: [ toolbarItems[ label ] label ] ];
	}
}

/******************************************************************************\
 * -frameForView:
 *
 * Return an outer window frame rectangle sufficient to correctly enclose the
 * given (sub)view, along with the parent window toolbar, title and any other
 * decoration it might have.
 * 
 * In:  ( NSView * ) view
 *      Subview to use for calculations.
 *
 * Out: ( NSRect )
 *      Rectangle to use as a parent window frame.
\******************************************************************************/

- ( NSRect ) frameForView: ( NSView * ) view
{
	NSRect windowFrame = [ [ self window ] frame ];
	NSRect contentRect = [ [ self window ] contentRectForFrameRect: windowFrame ];
	float  otherHeight = NSHeight( windowFrame ) - NSHeight( contentRect ); /* Toolbar, title, maybe other stuff */

	windowFrame.size.height = NSHeight ( [ view            frame ] ) + otherHeight;
	windowFrame.size.width  = NSWidth  ( [ view            frame ] );
	windowFrame.origin.y    = NSMaxY   ( [ [ self window ] frame ] ) - NSHeight( windowFrame );

	return windowFrame;
}

@end
