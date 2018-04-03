//
//  SlipCoverSupport.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 06/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import "SlipCoverSupport.h"
#import "ApplicationSupport.h"

#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

@interface SlipCoverSupport ()

+ ( void ) addCaseDefinitionsAt: ( NSString       * ) searchPath
                 toMutableArray: ( NSMutableArray * ) caseDefinitions;

+ ( NSURL * ) bookmarkedURLFor: ( NSString * ) searchPath;
@end

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
 *      subdirectories. Each directory will exist. If the SlipCover application
 *      or all of the likely subdirectores are absent, this method will return
 *      'nil'.
\******************************************************************************/

+ ( NSMutableArray * ) searchPathsForCovers
{
    NSString * appItself = [ self slipCoverApplicationPath ];
    if ( appItself == nil ) return nil;

    NSMutableArray * likelyFolders = [ ApplicationSupport applicationSupportDirectoriesFor: @"SlipCover" ];
    NSString       * caseFolder    =
    [
        NSString pathWithComponents:
        @[
            appItself,
            @"Contents",
            @"PlugIns",
            @"Cases"
        ]
    ];

    [ likelyFolders insertObject: caseFolder atIndex: 0 ];

    /* Is the application running in a sandbox? This is the only way I can find
     * to figure it out, even though it's clearly awful :-(
     */

    BOOL isSandboxed = NO;

    NSString * possibleSandboxHomePath =NSHomeDirectory();
    NSString * nonSandboxHomePath;
    
    struct passwd * pw = getpwuid( getuid() );

    /* If we have a result from getpwuid, compare the definitely non-sandbox
     * path to the possible-sandbox path. If the same - not sandboxed; else,
     * sandboxed.
     *
     * If we don't have a result from getpwuid, give up and use the horrible
     * hack of assuming "/Library/Containers" appears in the possible-sandbox
     * only if a sandbox is in use.
     */

    if ( pw )
    {
      nonSandboxHomePath = [ NSString stringWithUTF8String: pw->pw_dir ];

      if ( ! [ possibleSandboxHomePath isEqualToString: nonSandboxHomePath ] )
      {
          isSandboxed = YES;
      }
    }
    else
    {
        NSRange found = [ possibleSandboxHomePath rangeOfString: @"/Library/Containers/" ];

        if ( found.location != NSNotFound )
        {
            isSandboxed = YES;
        }
    }

    /* If we *are* sandboxed, hard-code an additional path to the user's
     * non-sandbox library for SlipCover styles there.
     */

    if ( isSandboxed )
    {
        NSString * nonSandboxPath = [ NSString stringWithFormat: @"%@/Library/Application Support/SlipCover", nonSandboxHomePath ];

        [ likelyFolders insertObject: nonSandboxPath atIndex: 0 ];
    }

    /* Between the application support directories, application itself and
     * non-sandbox library path, some or all of the items may not exist.
     */

    BOOL             exists, isDir;
    NSFileManager  * fileManager   = [ NSFileManager defaultManager ];
    NSMutableArray * actualFolders = [ [ NSMutableArray alloc ] init ];

    for ( NSString * path in likelyFolders )
    {
        exists = [ fileManager fileExistsAtPath: path isDirectory: &isDir ];

        if ( exists == YES && isDir == YES )
        {
            [ actualFolders addObject: path ];
        }
    }

    return [ actualFolders count ] == 0 ? nil : actualFolders;
}

/******************************************************************************\
 * +enumerateSlipCoverDefinitionsInto:thenCall:with:
 *
 * Generate an array of SlipCover CaseDefinition objects representing all
 * known and parseable case descriptors. This call is asynchronous; the
 * given selector is sent to the given object instance when complete, with
 * all of the case definitions included.
 *
 * In:  ( NSMutableArray * ) slipCoverDefinitions
 *      The caller provides an (assumed initially empty) NSMutableArray which
 *      will aynschronously be populated with CaseDefinition instances.
 *
 *      ( id ) instance
 *      When all accessible paths (inside the sandbox, exceptions, or outside
 *      the sandbox but with access granted) have been processed, this instance
 *      will be called to notify it that processing has finished.
 *
 *      ( SEL ) selector
 *      This is the no-parameters selector performed on the instance to notify
 *      it that all processing has finished. This selector is performed whether
 *      or not any case definitions were added to the provided mutable array.
\******************************************************************************/

+ ( void ) enumerateSlipCoverDefinitionsInto: ( NSMutableArray * ) slipCoverDefinitions
                                    thenCall: ( id               ) instance
                                        with: ( SEL              ) selector
{
    /* The main queue runs only one operation at a time and only in the main
     * thread. Perfect - that's what we need to check each search path and,
     * possibly, open a modal NSOpenPanel to grant access to one or more of
     * them, in series not parallel.
     *
     * Although we use -runModal: for the open panel, trying to do that in the
     * main thread synchronously while initialising stuff ends badly. Making
     * use of the main operation queue to schedule all of this in coordination
     * with anything else Mac OS X is doing works very well.
     */

    NSOperationQueue * mainQueue             = [ NSOperationQueue mainQueue ];
    NSMutableArray   * searchPaths           = [ self searchPathsForCovers ];
    NSMutableArray   * accessibleSearchPaths = [ [ NSMutableArray alloc ] init ];

    for ( NSString * searchPath in searchPaths )
    {
        [
            mainQueue addOperationWithBlock: ^ ( void )
            {
                BOOL       accessGranted = NO;
                NSURL    * bookmarkedURL = [ self bookmarkedURLFor: searchPath ];

                /* Under appropriate security scope, check access permission. If it is
                 * granted, easy! Just add it. Otherwise, try and get permission.
                 */

                [ bookmarkedURL startAccessingSecurityScopedResource ];

                if ( access( searchPath.fileSystemRepresentation, R_OK) == 0 )
                {
                    accessGranted = YES;
                    [ accessibleSearchPaths addObject: searchPath ];
                }
                
                [ bookmarkedURL stopAccessingSecurityScopedResource ];

                if ( accessGranted == NO )
                {
                    NSOpenPanel * openPanel = [ NSOpenPanel openPanel ];
                    NSURL       * fileURL   = [ NSURL fileURLWithPath: searchPath isDirectory: YES ];

                    [ openPanel setMessage: NSLocalizedString( @"Please click on the 'Grant Access' button to allow Add Folder Icons to offer SlipCover case design styles.", @"Message shown in the Open Panel used for granting out-of-sandbox access to the SlipCover application" ) ];
                    [ openPanel setPrompt:  NSLocalizedString( @"Grant Access", @"Button text in the Open Panel used for granting out-of-sandbox access to the SlipCover application"   ) ];

                    [ openPanel setCanChooseFiles:          NO  ];
                    [ openPanel setCanChooseDirectories:    YES ];
                    [ openPanel setCanCreateDirectories:    NO  ];
                    [ openPanel setAllowsMultipleSelection: NO  ];
                    [ openPanel setResolvesAliases:         YES ];

                    [ openPanel setDirectoryURL: fileURL ];

                    /* This blocks until a button is clicked upon */

                    NSModalResponse result = [ openPanel runModal ];

                    if ( result == NSFileHandlingPanelOKButton )
                    {
                        NSURL * url = openPanel.URLs[ 0 ];

                        if ( [ [ url absoluteString ] isEqualToString: [ fileURL absoluteString ] ] )
                        {
                            NSError * error        = nil;
                            NSData  * bookmarkData =
                            [
                                   url bookmarkDataWithOptions: NSURLBookmarkCreationWithSecurityScope
                                includingResourceValuesForKeys: nil
                                                 relativeToURL: nil
                                                         error: &error
                            ];

                            if ( error )
                            {
                                [ NSApp presentError: error ];
                            }
                            else
                            {
                                NSUserDefaults * userDefaults = [ NSUserDefaults standardUserDefaults ];
                                NSString       * prefsKey     = [ NSString stringWithFormat: @"BookmarkFor%@", searchPath ];

                                [ userDefaults setObject: bookmarkData forKey: prefsKey ];
                                [ userDefaults synchronize ];

                                [ accessibleSearchPaths addObject: searchPath ];
                            }
                        }
                    }
                }
            }
        ];
    }

    /* Once all the above paths have been processed, we'll have the
     * 'accessibleSearchPaths' array containing zero or more paths. Add in
     * another operation which takes those and builds case definitions.
     */

    [
        mainQueue addOperationWithBlock: ^ ( void )
        {
            for ( NSString * accessibleSearchPath in accessibleSearchPaths )
            {
                [ self addCaseDefinitionsAt: accessibleSearchPath
                             toMutableArray: slipCoverDefinitions ];
            }

            /* I.e.:
             *
             *   [ instance performSelector: selector ];
             *
             * See:
             *
             *   http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
             */

            IMP imp = [ instance methodForSelector: selector ];
            void ( *func )( id, SEL ) = (void * ) imp;
            func( instance, selector );
        }
    ];
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
 *           +enumerateSlipCoverDefinitionsInto:thenCall:with:
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

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Internal (private) methods.
//------------------------------------------------------------------------------

/******************************************************************************\
 * +bookmarkedURLFor:
 *
 * Internal.
 *
 * Return a security scoped bookmark for the given full POSIX path, or 'nil'
 * if no such thing exists.
 *
 * In:  ( NSString * ) searchPath
 *      Full POSIX path of the file or folder for which a bookmark is to be
 *      found.
 *
 * Out: NSURL for the security-scoped bookmark, or 'nil' if none is found.
 \******************************************************************************/

+ ( NSURL * ) bookmarkedURLFor: ( NSString * ) searchPath
{
    BOOL       isStale       = NO;
    NSError  * error         = nil;
    NSString * prefsKey      = [ NSString stringWithFormat: @"BookmarkFor%@", searchPath ];
    NSData   * bookmarkData  = [ [ NSUserDefaults standardUserDefaults ] objectForKey: prefsKey ];

    if ( bookmarkData )
    {
        NSURL * url = [ NSURL URLByResolvingBookmarkData: bookmarkData
                                                 options: NSURLBookmarkResolutionWithSecurityScope
                                           relativeToURL: nil
                                     bookmarkDataIsStale: &isStale
                                                   error: &error ];

        if ( error ) [ NSApp presentError: error ];

        if ( isStale == YES ) return nil;
        else                  return url;
    }
    else
    {
        return nil;
    }
}

/******************************************************************************\
 * +addCaseDefinitionsAt:toMutableArray:
 *
 * Internal.
 *
 * Enumerate SlipCover case definitions at a given search path and add
 * CaseDefinition objects representing all found and parseable case descriptors
 * to the given mutable array.
 *
 * In:  ( NSString * ) searchPath
 *      POSIX path of the folder in which case definitions may reside. If this
 *      is outside the sandbox, the user may have had to grant access else no
 *      successful enumeration will occur.
 *
 *      ( NSMutableArray *) caseDefinitions
 *      An array of existing CaseDefintion instances which may have new items
 *      added to the end.
 *
 * If any errors occur, the method silently exits without adding new entries to
 * the given array. Usually this happens when out-of-sandbox access has not
 * been granted for the given search path.
 \******************************************************************************/

+ ( void ) addCaseDefinitionsAt: ( NSString       * ) searchPath
                 toMutableArray: ( NSMutableArray * ) caseDefinitions
{
    NSURL * bookmarkedURL = [ self bookmarkedURLFor: searchPath ];
    BOOL    accessGranted = NO;

    /* If there's no security bookmark or access is somehow denied by it, maybe
     * there's an exception entitlement available instead so always check.
     */

    [ bookmarkedURL startAccessingSecurityScopedResource ];

    if ( access( searchPath.fileSystemRepresentation, R_OK) == 0 )
    {
        accessGranted = YES;
    }

    if ( accessGranted == YES )
    {
        NSFileManager * fileManager = [ [ NSFileManager alloc ] init ];
        NSArray       * contents    = [ fileManager contentsOfDirectoryAtPath: searchPath error: NULL ];

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

    [ bookmarkedURL stopAccessingSecurityScopedResource ];
}

@end
