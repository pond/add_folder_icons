//
//  SplashWindowController.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 26/05/2012.
//  Copyright 2012 Hipposoft. All rights reserved.
//

#import "SplashWindowController.h"

@implementation SplashWindowController

/******************************************************************************\
 * -initWithWindowNibName:
 *
 * Upon initialisation, this controller will open its window, put it at the
 * front of the normal stack and make it the key window. It is the caller's
 * responsibility to check that the value of the "showSplashScreenAtStartup"
 * preferences key is not 'NO' and only create an instance if so.
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
        /* Invoke 'window' to prompt lazy-load of the window, leading to
         * (amongst other things) '-windowDidLoad' being called.
         */

        [ self window ];
    }

    return self;
}

/******************************************************************************\
 * -windowDidLoad:
 *
 * The window loaded - open it in a centred position.
\******************************************************************************/

- ( void ) windowDidLoad
{
    [ super windowDidLoad ];

    /* The main window's NIB sets "released when closed" to NO, but the splash
     * window's NIB does not, so the splash window defaults to releasing itself
     * on close. On modern macOS that is fatal: when the splash window is the
     * key window and is closed, it is deallocated, yet AppKit's automatic
     * focus-ring machinery still references it when first-responder status
     * moves back to the main window. The result is a use-after-free crash in
     * +[_NSAutomaticFocusRing _clearOldFocusRing] -> -[NSWindow
     * _setNeedsDisplayInRegion:]. This controller owns the window for the
     * lifetime of the application, so keep it alive on close, matching the
     * behaviour already configured for the main window.
     */

    [ [ self window ] setReleasedWhenClosed: NO ];

    [ [ self window ] center ];
    [ [ self window ] makeKeyAndOrderFront: nil ];
}

/******************************************************************************\
 * -closeWindow:
 *
 * Close the window.
 *
 * In: ( NSButton * ) sender
 *     The button used to send this action message (ignored).
\******************************************************************************/

- ( IBAction ) closeWindow: ( NSButton * ) sender
{
    ( void ) sender;

    /* Resign first responder before the window goes away so that AppKit tears
     * down any focus ring while the window is still a valid object.
     */

    [ [ self window ] makeFirstResponder: nil ];
    [ self close ];
}

@end
