//
//  SplashWindowController.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 26/05/2012.
//  Copyright 2012 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SplashWindowController : NSWindowController
{
    IBOutlet NSView * mainView;
}

- ( IBAction ) closeWindow: ( NSButton * ) sender;

@end
