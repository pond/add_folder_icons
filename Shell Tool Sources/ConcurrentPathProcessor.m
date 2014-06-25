/******************************************************************************\
 * addfoldericons: ConcurrentPathProcessor.m
 *
 * Derive a class from NSOperation which can be used to concurrently process a
 * full POSIX path to a folder in order to update that folder's icon. The class
 * may be run by, for example, adding it as an operation to an NSOperationQueue
 * instance.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#include <stdio.h>

/* Application functions and data */

#import "ConcurrentPathProcessor.h"
#import "GlobalConstants.h"

/* Library functions and data */

#import "GlobalSemaphore.h"
#import "Icons.h"
#import "IconGenerator.h"

/* Application communication */

#import "FolderProcessNotificationProtocol.h"

@implementation ConcurrentPathProcessor

@synthesize pathData       = _pathData;
@synthesize backgroundRef  = _backgroundRef;
@synthesize iconParameters = _iconParameters;

/******************************************************************************\
 * - initWithPath:andBackground:andParameters:
 *
 * Initialise the NSOperation derivative class. Local copies are taken of all
 * objects given in the input parameters so the caller can discard its own
 * copy immediately after calling if it so wishes.
 *
 * The global semaphore system must be initialised before calling here. See
 * "globalSemaphoreInit" in "GlobalSemaphore.[h|m]".
 *
 * In:  Pointer to an NSString giving the full POSIX path to the folder of
 *      interest - this folder will be given a custom icon if the object's
 *      "main" method gets invoked;
 *
 *      CGImageRef giving a background image - for more information, see the
 *      documentation in the library code for the "backgroundImage" parameter
 *      of "allocIconForFolder" in "IconGenerator.[h|m]";
 *
 *      Pointer to an initialised IconParameters instance describing how the
 *      icons should be generated. Only a reference to this is kept; the caller
 *      is responsible for maintaining that object until the path processor is
 *      finished with. This is done to save CPU cycles and RAM when dealing
 *      with large numbers of paths all using the same icon style, particularly
 *      when that style refers itself to an external complex structure such as
 *      a SlipCover case descriptor.
 *
 * Out: self.
\******************************************************************************/

-( id ) initWithPath : ( NSString       * ) fullPosixPath
       andBackground : ( CGImageRef       ) backgroundImage
       andParameters : ( IconParameters * ) params;
{
    if ( ( self = [ super init ] ) )
    {
        self.pathData       = fullPosixPath;
        self.backgroundRef  = allocFolderIcon();//CGImageCreateCopy( backgroundImage );
        self.iconParameters = params;
    }

    return self;
}

/******************************************************************************\
 * - initWithpath
 *
 * Release any and all resources claimed during the object's lifecycle. Usually
 * invoked only by the Grand Central Dispatch mechanism's Cocoa code.
\******************************************************************************/

-( void ) dealloc
{
    CFRelease( self.backgroundRef );
}

/******************************************************************************\
 * - main
 *
 * Main processing loop. Usually invoked only by the Grand Central Dispatch
 * mechanism's Cocoa code. The folder given in "initWithPathAndBackground"
 * will have gained an updated icon on exit provided there were no errors.
\******************************************************************************/

-( void ) main
{
    @autoreleasepool
    {
        @try
        {
            /* Generate the thumbnail */

            OSStatus   status     = noErr;
            CGImageRef finalImage = allocIconForFolder
            (
                self.pathData,
                NO,
                SKIP_PACKAGES,
                self.backgroundRef,
                &status,
                self.iconParameters
            );

            if ( finalImage )
            {
                /* Debugging option - dump the icon data to a file with a name based
                 * on the folder's name, alongside that folder.
                 *
                 * See also "GlobalConstants.h".
                 */
                
                #ifdef DUMP_ICON_MASTER_IMAGE_TO_PNG_FILE

                    NSString * dumpPath = [ [ pathData stringByAppendingString: @"__AddFolderIconsDumpedIcon__.png" ] retain ];
                    NSURL    * dumpURL  = [ [ NSURL fileURLWithPath: dumpPath ] retain ];

                    CGImageDestinationRef imageDest = CGImageDestinationCreateWithURL
                    (
                        ( CFURLRef ) dumpURL, /* "Toll-free bridge" */
                        kUTTypePNG,
                        1,
                        NULL
                    );
                    
                    /* Since this is a debugging function, we're not interested in
                     * detecting or attempting to report problems at run-time.
                     */
                    
                    if ( imageDest )
                    {
                        CGImageDestinationAddImage( imageDest, finalImage, NULL );
                        ( void ) CGImageDestinationFinalize( imageDest );
                        CFRelease( imageDest );
                    }

                    [ dumpPath release ];
                    [ dumpURL  release ];

                #endif    

                /* Apply the thumbnail to the folder. Since the global
                 * semaphore is needed here, an inned try...catch construct
                 * is required to ensure it gets released whatever happens.
                 */

                [ [ NSWorkspace sharedWorkspace ] setIcon: nil forFile: self.pathData options: 0 ];

                IconFamilyHandle iconHnd = NULL;
                status = createIconFamilyFromCGImage( finalImage, &iconHnd );

                if ( status == noErr && iconHnd != NULL )
                {
                    @try
                    {
                        globalSemaphoreClaim();
                        status = saveCustomIcon( self.pathData, iconHnd );
                        globalSemaphoreRelease();
                    }
                    @catch ( NSException * exception )
                    {
                        globalSemaphoreRelease();

                        NSLog
                        (
                            @"%@ (saveCustomIcon()): Exception '%@': %@",
                            @PROGRAM_STRING,
                            [ exception name   ],
                            [ exception reason ]
                        );
                        
                        @throw exception;
                    }

                    DisposeHandle( ( Handle ) iconHnd );
                }

                CFRelease( finalImage );
            }

            if ( status != noErr )
            {
                NSLog
                (
                    @"%@: Failed for '%@' with OSStatus code %d (&%04X) and errno value %d (&%04X): %@",
                    @PROGRAM_STRING,
                    self.pathData,
                    ( int          ) status,
                    ( unsigned int ) status,
                    ( int          ) errno,
                    ( unsigned int ) errno,
                    @( strerror( errno ) )
                );

                globalSemaphoreClaim();
                globalErrorFlag = YES;
                globalSemaphoreRelease();
            }
        }
        @catch ( NSException * exception )
        {
            NSLog
            (
                @"%@: Exception '%@': %@",
                @PROGRAM_STRING,
                [ exception name   ],
                [ exception reason ]
            );

            globalSemaphoreClaim();
            globalErrorFlag = YES;
            globalSemaphoreRelease();
        }

        /* If we reach here with no error and there is an a known communications
         * channel, use it to tell the application about our progress.
         */

        if ( globalErrorFlag == NO && self.iconParameters.commsChannel )
        {
            /* See FolderProcessNotificationProtocol.h */

            id proxy =
            [
                NSConnection rootProxyForConnectionWithRegisteredName: self.iconParameters.commsChannel
                                                                 host: nil
            ];

            [ proxy setProtocolForProxy: @protocol( FolderProcessNotification ) ];

            if ( [ proxy folderProcessedSuccessfully: self.pathData ] == YES )
            {
                globalSemaphoreClaim();
                globalErrorFlag = YES;
                globalSemaphoreRelease();
            }
        }

    } // @autoreleasepool
}

@end /* @implementation ConcurrentPathProcessor */
