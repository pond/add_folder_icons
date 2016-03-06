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

#import "ConcurrentPathProcessor.h"

#import "GlobalConstants.h"
#import "GlobalSemaphore.h"
#import "Icons.h"
#import "CustomIconGenerator.h"

/* Application communication */

@implementation ConcurrentPathProcessor

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
 * In:  ( IconStyle * ) iconStyle
 *      Pointer to the base IconStyle instance to use for icon generation. This
 *      and the POSIX path parameter below are passed to a CustomIconGenerator
 *      initialiser, so see that class for more details. The generator does the
 *      heavy lifting of actual image generation, with other support code used
 *      to take that image and apply it to a folder as an icon.
 *
 *      ( NSString * ) posixPath
 *      Pointer to an NSString giving the full POSIX path to the folder of
 *      interest - this folder will be given a custom icon if the object's
 *      "main" method gets invoked.
 *
 * Out: self.
\******************************************************************************/

- ( instancetype ) initWithIconStyle: ( IconStyle * ) iconStyle
                        forPOSIXPath: ( NSString  * ) posixPath;
{
    if ( ( self = [ super init ] ) )
    {
        _pathData      = posixPath;
        _iconGenerator = [
            [ CustomIconGenerator alloc ] initWithIconStyle: iconStyle
                                               forPOSIXPath: posixPath
        ];
    }

    return self;
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
            NSError  * error  = nil;
            OSStatus   status = noErr;

            if ( self.isCancelled ) return;

            /* Generate the thumbnail */

            CGImageRef finalImage = [ _iconGenerator generate: & error ];

            if ( self.isCancelled ) return;

            if ( finalImage )
            {
                /* Debugging option - dump the icon data to a file with a name based
                 * on the folder's name, alongside that folder.
                 *
                 * See also "GlobalConstants.h".
                 */
                
                #ifdef DUMP_ICON_MASTER_IMAGE_TO_PNG_FILE

                    NSString * dumpPath = [ _pathData stringByAppendingString: @"/__AddFolderIconsDumpedIcon__.png" ];
                    NSURL    * dumpURL  = [ NSURL fileURLWithPath: dumpPath ];

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

                #endif    

                /* The Finder gets buggier with each OS release and by
                 * Mavericks and especially Yosemite is extremely reluctant
                 * to update the view when a folder icon *changes* but tends
                 * to perform better if the icon is *removed then added*, so
                 * remove it first here.
                 *
                 * It's pretty depressing how consistently changes to objects
                 * result in no Finder view updates, even if QuickLook shows
                 * the changes immediately.
                 */

                [ [ NSWorkspace sharedWorkspace ] setIcon: nil forFile: self.pathData options: 0 ];

                /* Apply the thumbnail to the folder. Since the global
                 * semaphore is needed here, an inned try...catch construct
                 * is required to ensure it gets released whatever happens.
                 */

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

    } // @autoreleasepool
}

@end /* @implementation ConcurrentPathProcessor */
