/******************************************************************************\
 * Utilities: Miscellaneous.m
 *
 * Miscellaneous useful functions.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import "Miscellaneous.h"

/******************************************************************************\
 * getUti()
 *
 * Pass a reference to a file. Returns the UTI or NULL on error.
 *
 * In:  Pointer to FSRef for file of interest.
 *
 * Out: UTI (as a reference to a CFString) or NULL on error. Caller must
 *      release the string later, for non-NULL return values.
\******************************************************************************/

CFStringRef getUti( FSRef * fsRef )
{
    CFTypeRef uti = NULL;

    ( void ) LSCopyItemAttribute
    (
        fsRef,
        kLSRolesViewer,
        kLSItemContentType,
        &uti
    );

    /* Attribute "kLSItemContentType" returns a CFStringRef value type */

    return ( CFStringRef ) uti;
}

/******************************************************************************\
 * isLikeAPackage()
 *
 * Pass a fully specified POSIX-style file path. Returns YES if it is a
 * directory representing an application or general bundle/package. Returns NO
 * otherwise. If an error is encountered, always returns NO. Distantly related
 * to listing 6 of:
 *
 *   http://developer.apple.com/technotes/tn2002/tn2078.html
 *
 * Usually only called for paths pointing to things you already know are a
 * kind of directory, else the NO return value is ambiguous (could be a file
 * or a folder with no package-like behaviour).
 *
 * In:  Full POSIX path of file of interest.
 *
 * Out: YES if the directory has package-like behaviour, NO if it is just a
 *      plain directory or an internal error is encountered.
\******************************************************************************/

Boolean isLikeAPackage( NSString * fullPosixPath )
{
    Boolean isLikeAPackage = NO;
    FSRef   fileRef;
    Boolean isDirectory;

    if (
           FSPathMakeRef
           (
               ( const UInt8 * ) [ fullPosixPath fileSystemRepresentation ],
               &fileRef,
               &isDirectory
           )
           == noErr
       )
    {
        LSItemInfoRecord info;

        if (
               isDirectory &&
               LSCopyItemInfoForRef
               (
                   &fileRef,
                   kLSRequestBasicFlagsOnly,
                   &info
               )
               == noErr
           )
        {
            if (
                   ( kLSItemInfoIsApplication &info.flags ) != 0 ||
                   ( kLSItemInfoIsPackage     &info.flags ) != 0
               )
               isLikeAPackage = YES;
        }
    }

    return isLikeAPackage;
}

/******************************************************************************\
 * isImageFile()
 *
 * Pass a fully specified POSIX-style file path. Returns YES if the path
 * points to a recognised image file, else NO. Adpted from:
 *
 *   http://developer.apple.com/qa/qa2007/qa1518.html
 *
 * In:  Full POSIX path of file of interest.
 *
 * Out: YES if the file is an image which the OS can display, else NO. This is
 *      based purely on the file UTI; the actual file data may turn out to be
 *      corrupt in some way if it is eventually loaded.
\******************************************************************************/

Boolean isImageFile( NSString * fullPosixPath )
{
    Boolean isImageFile = NO;
    FSRef   fileRef;
    Boolean isDirectory;

    if (
           FSPathMakeRef
           (
               ( const UInt8 * ) [ fullPosixPath fileSystemRepresentation ],
               &fileRef,
               &isDirectory
           )
           == noErr
       )
    {
        CFStringRef uti = getUti( &fileRef );

        if ( uti != NULL )
        {
            CFArrayRef supportedTypes = CGImageSourceCopyTypeIdentifiers();
            CFIndex    typeCount      = CFArrayGetCount( supportedTypes );
            CFIndex    i;

            for ( i = 0; i < typeCount; i++ )
            {
                CFStringRef supportedUTI = CFArrayGetValueAtIndex
                (
                    supportedTypes,
                    i
                );

                /* Make sure the supported UTI conforms only to
                 * "public.image" to skip e.g. PDFs.
                 */

                if ( UTTypeConformsTo( supportedUTI, CFSTR( "public.image" ) ) )
                {
                    if ( UTTypeConformsTo( uti, supportedUTI ) )
                    {
                        isImageFile = YES;
                        break;
                    }
                }
            }

            CFRelease( supportedTypes );
            CFRelease( uti            );
        }
    }

    return isImageFile;
}

/******************************************************************************\
 * sendFinderAppleEvent()
 *
 * Send the Finder an event within its kAEFinderSuite. Originates from:
 *
 *   http://developer.apple.com/samplecode/SetCustomIcon/
 *
 * In:  AliasHandle for an alias indicating the object of interest for the
 *      Finder (e.g. the folder which has just had its icon updated);
 *
 *      Event ID (e.g. "kAESync" to tell the Finder to update its display(s)
 *      of the folder, if any, immediately).
 *
 * Out: OSErr indicating success (noErr) or failure (anything else).
\******************************************************************************/

OSErr sendFinderAppleEvent( AliasHandle aliasH, AEEventID appleEventID )
{
    ProcessInfoRec      processInfo;
    OSErr               err;
    AppleEvent          appleEvent = { typeNull,   NULL       };
    AEDesc              aeDesc     = { typeNull,   NULL       };
    ProcessSerialNumber psn        = { kNoProcess, kNoProcess };
    AppleEvent          aeReply    = { typeNull,   NULL       };

    /* Iterate through all processes looking for the Finder */

    bzero( ( Ptr ) &processInfo, sizeof( processInfo ) );
    processInfo.processInfoLength = sizeof( processInfo );

    for (
            err =  GetNextProcess( &psn );
            err == noErr;
            err =  GetNextProcess( &psn )
        )
    {
        err = GetProcessInformation( &psn, &processInfo );

        if (
               ( processInfo.processSignature == 'MACS' ) &&
               ( processInfo.processType      == 'FNDR' )
           )
           break;
    }

    require_noerr( err, bailOut );

    /* Create the AppleEvent (kAEFinderSuite, appleEventID) */

    err = AECreateDesc
    (
        typeProcessSerialNumber,
        &psn,
        sizeof( psn ),
        &aeDesc
    );

    require_noerr( err, bailOut );

    err = AECreateAppleEvent
    (
        kAEFinderSuite,
        appleEventID,
        &aeDesc,
        kAutoGenerateReturnID,
        kAnyTransactionID,
        &appleEvent
    );

    ( void ) AEDisposeDesc( &aeDesc );
    require_noerr( err, bailOut );

    /* Send the AppleEvent */

    err = AECreateDesc
    (
        typeAlias,
        *aliasH,
        GetHandleSize( ( Handle ) aliasH ),
        &aeDesc
    );

    require_noerr( err, bailOut );

    err = AEPutParamDesc( &appleEvent, keyDirectObject, &aeDesc );
    (void) AEDisposeDesc( &aeDesc );
    require_noerr( err, bailOut );

    err = AESend
    (
        &appleEvent,
        &aeReply,
        kAENoReply,
        kAENormalPriority,
        kNoTimeOut,
        NULL,
        NULL
    );

    (void) AEDisposeDesc( &aeReply );
    require_noerr( err, bailOut );

    (void) AEDisposeDesc( &appleEvent );

bailOut:

    return err;
}

/******************************************************************************\
 * dpiValue()
 *
 * When given a value representing part of a position or object dimension for
 * graphics, return an equivalent value taking into account high DPI ("retina")
 * displays if the OS supports it (in short, conditionally multiply by 2!).
 *
 * In:  Uncorrected (standard pixel density) value.
 *
 * Out: Input value, or input value multiplied by 2 on "new enough" OS
 *      versions (10.7 "Lion" or later).
\******************************************************************************/

NSInteger dpiValue( NSInteger uncorrectedValue )
{
    if ( floor( NSAppKitVersionNumber ) > NSAppKitVersionNumber10_6 )
    {
        return uncorrectedValue * 2;
    }
    else
    {
        return uncorrectedValue;
    }
}
