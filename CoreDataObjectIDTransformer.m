//
//  CoreDataObjectIDTransformer.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 21/01/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//
//  Converts from a NSManagedObjectID to an NSString and vice versa.
//
//  A persistent store coordinator reference MUST be supplied before the
//  transformer will work. See "-setPersistentStoreCoordinator:"
//  (synthesized). Without this, forwards transformation will always result
//  in a result of 'nil'.
//
//  This value transformer is intended to be used with pop-up menus bound to
//  an array controller managing a CoreData collection of icon styles. The
//  content should be bound to the controller's arranged objects (no key path),
//  the content objects be bound to the "objectID" key path and the content
//  values be bound to the "name" key path. Thus the menu displays style names
//  but records unique CoreData object IDs internally.
// 
//  If the result of the selection needs to be stored in e.g. a preferences
//  file, the menu's selected object is bound to e.g. the shared user defaults
//  controller for whatever key path is to be used to record the selection in
//  the preferences (e.g. "defaultStyle" to store a chosen default icon style).
//  However, this would fail because only easily serialised data such as an
//  NSString can be written to a property list without a value transformer.
// 
//  Thus, specify "CoreDataObjectIDTransformer" as a value transformer for
//  the content objects binding of the menu. Specify the same as a value
//  transformer for the selected object binding. The transformer takes the
//  object ID and turns it into an NSString or vice versa.
//

#import "CoreDataObjectIDTransformer.h"

@implementation CoreDataObjectIDTransformer

@synthesize persistentStoreCoordinator;

/******************************************************************************\
 * +allowsReverseTransformation
 *
 * NSValueTransformer: Indicate that the class supports reverse transformation.
 *
 * Out: ( BOOL )
 *      YES, always.
\******************************************************************************/

+ ( BOOL ) allowsReverseTransformation
{
    return YES;
}

/******************************************************************************\
 * +transformValueClass
 *
 * NSValueTransformer: Indicate that the class returns an NSManagedObjectID.
 *
 * Due to the intended usage and the way that the bindings described at the
 * top this file lead to the transformer being called, the direction of
 * transformation is *from* NSString and *to* NSManagedObjectID.
 *
 * Out: ( Class )
 *      Class of NSManagedObjectID, always.
\******************************************************************************/

+ ( Class ) transformValueClass
{
    /* The 'forwards direction' transformation is *from* NSString *to*
     * NSManagedObjectID, via NSURL internally.
     */

    return [ NSManagedObjectID class ];
};

/******************************************************************************\
 * -transformedValue:
 *
 * NSValueTransformer: Convert an NSString to an NSManagedObjectID.
 *
 * In:  ( id )
 *      Pointer to an NSString cast to 'id', or nil. The string must represent
 *      a URL, which in turn is a URL representation of the required object ID.
 *
 * Out: ( id )
 *      Pointer to an equivalent NSManagedObjectID cast to 'id', or nil.
\******************************************************************************/

- ( id ) transformedValue: ( id ) value
{
    if ( value == nil ) return nil;

    NSString * str = ( NSString * ) value;
    NSURL    * uri = [ NSURL URLWithString: str ];

    return ( id ) [ persistentStoreCoordinator managedObjectIDForURIRepresentation: uri ];
}

/******************************************************************************\
 * -reverseTransformedValue:
 *
 * NSValueTransformer: Convert an NSManagedObjectID to an NSString.
 *
 * In:  ( id )
 *      Pointer to an NSManagedObjectID cast to 'id', or nil.
 *
 * Out: ( id )
 *      Pointer to an equivalent NSString cast to 'id', or nil.
\******************************************************************************/

- ( id ) reverseTransformedValue: ( id ) value
{
    if ( value == nil ) return nil;

    NSManagedObjectID * objID = ( NSManagedObjectID * ) value;
    NSURL             * uri   = [ objID URIRepresentation ];

    return ( id ) [ uri absoluteString ];
}

@end
