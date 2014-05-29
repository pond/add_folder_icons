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

- ( id ) initWithWindowNibName: ( NSString * ) windowNibName
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
    [ self close ]; 
}

@end
