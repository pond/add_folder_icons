//
//  IconStyleArrayController.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 24/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//
//  This subclass exists only so that a default sort descriptor (by name
//  ascending) can be easily applied to any place where an icon style list
//  is generated, without duplicating code or convoluted bindings.
//

#import "IconStyleArrayController.h"

@implementation IconStyleArrayController

/* Overriding all three NSArrayController initialisation methods is probably
 * overkill; it seems to me that there must be a more elegant and less
 * overweight way to achieve this apparently simple requirement of specifying
 * default sorting for a CoreData bound array controller. However, despite
 * two days attempting to read around the topic on developer.apple.com and
 * numerous articles turned up via Google, table views listing styles still
 * always default to unsorted until a column heading is clicked upon, popup
 * menus of styles are never sorted and so-on. In the end I abandoned various
 * Interface Builder/defaults/bindings based schemes and just wrote the code
 * below. Each NIB including one of these controllers will thus inherit the
 * intended default sort order automatically.
 */

//TODO: There must be a better way! Revisit this sometime.

- ( id ) init
{
    self = [ super init ];
    [ self setDefaultSortDescriptors ];
    return self;
}

- ( id ) initWithCoder: ( NSCoder * ) aDecoder
{
    self = [ super initWithCoder: aDecoder ];
    [ self setDefaultSortDescriptors ];
    return self;
}

- ( id ) initWithContent: ( id ) content 
{
    self = [ super initWithContent: content ];
    [ self setDefaultSortDescriptors ];
    return self;
}

- ( void ) setDefaultSortDescriptors
{
    /* By name, ascending then by creation date, ascending, so that the sort
     * order remains stable if a user defines styles with the same name.
     */

    NSSortDescriptor * byNameDescriptor =
    [
        [ NSSortDescriptor alloc ] initWithKey: @"name"
                                     ascending: YES
    ];

    NSSortDescriptor * byDateDescriptor =
    [
        [ NSSortDescriptor alloc ] initWithKey: @"createdAt"
                                     ascending: YES
    ];

    NSArray * iconStyleSortDescriptors =
    @[
        byNameDescriptor,
        byDateDescriptor
    ];

    [ self setSortDescriptors: iconStyleSortDescriptors ];

}

@end
