//
//  IconStyleArrayController.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 24/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//
//  This subclass exists only so that a default sort descriptor (by name
//  ascending) can be easily applied to any place where an icon style list
//  is generated, without duplicating code or convoluted bindings.
//

#import <Cocoa/Cocoa.h>

@interface IconStyleArrayController : NSArrayController
{
}

- ( void ) setDefaultSortDescriptors;

@end
