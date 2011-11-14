//
//  ApplicationSupport.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 03/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* Note that any ancillary components such as exported system Services must
 * 'agree' on this path, so although changing it here will update any of the
 * Objective C sources herein, you may also need to update components written
 * in other languages.
 *
 * Guidelines indicate that the Application Resources subfolder should be
 * named after the application's human-readable name or its bundle ID, though,
 * so there isn't much scope for modification.
 */

#define APPLICATION_SUPPORT_DIRECTORY_FILENAME @"uk.org.pond.Add-Folder-Icons"

@interface ApplicationSupport : NSObject
{
}

+ ( NSString       * ) applicationSupportDirectory;
+ ( NSMutableArray * ) applicationSupportDirectoriesFor: ( NSString * ) name;
+ ( NSString       * ) resourcePathFor:                  ( NSString * ) name;
+ ( NSString       * ) auxiliaryExecutablePathFor:       ( NSString * ) name;

+ ( BOOL             ) copyItemToApplicationSupport: ( NSString * ) leafname
                                       isExecutable: ( BOOL       ) isExecutable
                                            ifNewer: ( BOOL       ) ifNewer
                                              error: ( NSError ** ) error;

@end
