//
//  SlipCoverSupport.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 06/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "SlipCoverSupport.h"
#import "ApplicationSupport.h"

@implementation SlipCoverSupport

/******************************************************************************\
 * +slipCoverApplicationPath
 *
 * Find the full POSIX path to the SlipCover application bundle.
 *
 * Out: ( NSString * )
 *      Autoreleased pointer to the full POSIX path of the SlipCover
 *      application bundle, or 'nil' if the application cannot be found.
\******************************************************************************/

+ ( NSString * ) slipCoverApplicationPath
{
    NSWorkspace * workspace = [ NSWorkspace sharedWorkspace ];
    return [ workspace absolutePathForAppBundleWithIdentifier: @"com.bohemiancoding.slipcover" ];
}

/******************************************************************************\
 * +searchPathsForCovers
 *
 * Return an array of search paths for SlipCover case files.
 *
 * Out: ( NSMutableArray * )
 *      Autoreleased array of autoreleased pointers to NSStrings each giving
 *      the full POSIX path of a unique directory which might contain SlipCover
 *      case files. Each directory can be assumed to have no interesting
 *      subdirectories. Each directory may or may not exist. If the SlipCover
 *      application cannot be found, this method will return 'nil'.
\******************************************************************************/

+ ( NSMutableArray * ) searchPathsForCovers
{
    NSString * appItself = [ self slipCoverApplicationPath ];
    if ( appItself == nil ) return nil;

    NSMutableArray * appSupport = [ ApplicationSupport applicationSupportDirectoriesFor: @"SlipCover" ];
    NSString       * caseFolder =
    [
        NSString pathWithComponents:
        [
            NSArray arrayWithObjects: appItself,
                                      @"Contents",
                                      @"PlugIns",
                                      @"Cases",
                                      nil
        ]
    ];

    [ appSupport insertObject: caseFolder atIndex: 0 ];
    return appSupport;
}

/******************************************************************************\
 * +enumerateSlipCoverDefinitions
 *
 * Return an array of SlipCover CaseDefinition objects representing all
 * known and parseable case descriptors.
 *
 * Out: ( NSMutableArray * )
 *      Autoreleased array of autoreleased pointers to CaseDefinitions or 'nil'
 *      if no valid case definitions could be found.
\******************************************************************************/

+ ( NSMutableArray * ) enumerateSlipCoverDefinitions
{
    NSFileManager  * fileManager     = [ [ NSFileManager alloc ] init ];
    NSMutableArray * searchPaths     = [ self searchPathsForCovers ];
    NSMutableArray * caseDefinitions = [ NSMutableArray arrayWithCapacity: 0 ];

    for ( NSString * searchPath in searchPaths )
    {
        NSArray * contents = [ fileManager contentsOfDirectoryAtPath: searchPath error: NULL ];

        if ( contents != nil )
        {
            for ( NSString * casePath in contents )
            {
                /* The CaseDefinition constructor code handles sanity checks
                 * and returns 'nil' if anything goes wrong. 
                 */
                 
                CaseDefinition * caseDefinition =
                [
                    CaseDefinition caseDefinitionFromPath:
                    [ searchPath stringByAppendingPathComponent: casePath ]
                ];

                if ( [ caseDefinition name ] != nil )
                {
                    [ caseDefinitions addObject: caseDefinition ];
                }
            }
        }
    }

    [ fileManager release ];

    if ( [ caseDefinitions count ] == 0 ) return nil;
    else                                  return caseDefinitions;
}

/******************************************************************************\
 * +findDefinitionFromName:
 *
 * Enumerates the current set of available SlipCover case definitions, then
 * passes the given name and the array of definitions through to
 * "+findDefinitionFromName:withinDefinitions:". As a result the returned
 * object is an autoreleased item that is not owned by the caller.
 *
 * If you already have an enumerated set of case definitions available, it is
 * more efficient to use "+findDefinitionFromName:withinDefinitions:" directly.
 *
 * In:       ( NSString * ) name
 *           Name of case definition to find.
 *
 * Out:      ( CaseDefinition * )
 *           Pointer to a case definition if found, else nil.
 *
 * See also: +findDefinitionFromName:withinDefinitions:
\******************************************************************************/

+ ( CaseDefinition * ) findDefinitionFromName: ( NSString * ) name
{
    return [ self findDefinitionFromName: name
                       withinDefinitions: [ self enumerateSlipCoverDefinitions ] ];
}

/******************************************************************************\
 * +findDefinitionFromName:withinDefinitions:
 *
 * Given a name, find a corresponding SlipCover definition from within a given
 * array of definitions. The match is made case insensitively but without
 * locale awareness, on the basis of case names being derived from filesystem
 * paths.
 *
 * The ownership of the returned object depends upon the ownership of the
 * given case definitions array.
 *
 * In:       ( NSString * ) name
 *           Name of case definition to find;
 *
 *           ( NSArray * ) caseDefinitions
 *           Array of pointers to CaseDefinition objects to search through.
 *
 * Out:      ( CaseDefinition * )
 *           Pointer to a case definition if found, else nil.
 *
 * See also: +findDefinitionFromName:
 *           +enumerateSlipCoverDefinitions
\******************************************************************************/

+ ( CaseDefinition * ) findDefinitionFromName: ( NSString * ) name
                            withinDefinitions: ( NSArray  * ) caseDefinitions
{
    CaseDefinition * foundDefinition = nil;

    /* Look for the requested name with a simple loop; if more than one
     * case has the same name when compared case-insensitive (since by
     * default Mac OS systems have case-insensitive file systems,
     * though this isn't always the case), then whichever happens to
     * come up first is chosen - basically, it'll be arbitrary. Other
     * ways of identifying cases based on e.g. some kind of unique ID
     * added into the SlipCover source code might be possible, but it
     * just doesn't seem worth the effort for such an unlikely edge
     * case.
     */

    for ( CaseDefinition * caseDefinition in caseDefinitions )
    {
        if ( [ [ caseDefinition name ] caseInsensitiveCompare: name ] == NSOrderedSame )
        {
            foundDefinition = caseDefinition;
            break;
        }
    }

    return foundDefinition;
}

@end
