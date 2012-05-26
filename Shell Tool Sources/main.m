/******************************************************************************\
 * addfoldericons - command line program to assign an icon to a folder
 * which gives an indication of any images held inside that folder, or
 * any of its sub-folders.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
 *
 * For licence conditions, see the application bundle Credits.rtf file.
\******************************************************************************/

#include <stdio.h>
#include <sysexits.h>

#import <Cocoa/Cocoa.h>

/* Application functions and data */

#import "GlobalConstants.h"
#import "ConcurrentPathProcessor.h"
#import "SlipCoverSupport.h"
#import "IconParameters.h"

Boolean globalErrorFlag = NO; /* See GlobalConstants.h */

/* Library functions and data */

#import "Icons.h"
#import "GlobalSemaphore.h"

/* Local functions */

static void printHelp    ( void );
static void printVersion ( void );

/******************************************************************************\
 * First thing's first...
\******************************************************************************/

int main( int argc, const char * argv[] )
{
    @autoreleasepool
    {

        /* Establish default parameters which command line arguments can override */

        IconParameters * params = [ [ IconParameters alloc ] init ];

        params.commsChannel           = nil;
        params.previewMode            = NO;

        params.slipCoverCase          = nil;
        params.crop                   = NO;
        params.border                 = NO;
        params.shadow                 = NO;
        params.rotate                 = NO;
        params.maxImages              = 4;
        params.showFolderInBackground = StyleShowFolderInBackgroundForOneOrTwoImages;
        params.singleImageMode        = NO;
        params.useColourLabels        = NO;
        params.coverArtNames          =
        [
            NSMutableArray arrayWithObjects: [ NSString stringWithUTF8String: "folder" ],
                                             [ NSString stringWithUTF8String: "cover"  ],
                                             nil
        ];

        int arg = 1;
        while ( arg < argc )
        {
            /* Simple boolean switches */
        
            if      ( ! strcmp( argv[ arg ], "--crop"   ) ) params.crop            = YES;
            else if ( ! strcmp( argv[ arg ], "--border" ) ) params.border          = YES;
            else if ( ! strcmp( argv[ arg ], "--shadow" ) ) params.shadow          = YES;
            else if ( ! strcmp( argv[ arg ], "--rotate" ) ) params.rotate          = YES;
            else if ( ! strcmp( argv[ arg ], "--single" ) ) params.singleImageMode = YES;
            else if ( ! strcmp( argv[ arg ], "--labels" ) ) params.useColourLabels = YES;

            /* Numerical parameters */

            else if ( ! strcmp( argv[ arg ], "--maximages"  ) && ( ++ arg ) < argc ) params.maxImages              = atoi( argv[ arg ] );
            else if ( ! strcmp( argv[ arg ], "--showfolder" ) && ( ++ arg ) < argc ) params.showFolderInBackground = atoi( argv[ arg ] );

            /* String parameters */
            
            else if ( ! strcmp( argv[ arg ], "--communicate" ) && ( ++ arg ) < argc )
            {
                /* The public usage string does not print this argument out as it
                 * is for internal use between the CLI tool and application. The
                 * application provides its NSConnection server name here.
                 */

                params.commsChannel = [ NSString stringWithUTF8String: argv[ arg ] ];
            }

            /* SlipCover definition - this one is more complicated as we have to
             * generate the case definition from the name and store the definition
             * reference in the icon style parameters.
             */

            else if ( ! strcmp( argv[ arg ], "--slipcover" ) && ( ++ arg ) < argc )
            {
                NSString       * requestedName   = [ NSString stringWithUTF8String: argv[ arg ] ];
                CaseDefinition * foundDefinition = [ SlipCoverSupport findDefinitionFromName: requestedName ];

                if ( foundDefinition == nil )
                {
                    printVersion();
                    printf( "SlipCover case name '%s' is not recognised.\n", argv[ arg ] );
                    return EX_USAGE;
                }

                params.slipCoverCase = foundDefinition;
            }

            /* Array - the second parameter after the switch is the number of
             * items, followed by the items themselves.
             */
            
            else if ( ! strcmp( argv[ arg ], "--coverart" ) && ( arg + 2 ) < argc )
            {
                int              count = atoi( argv[ ++ arg ] );
                NSMutableArray * array = [ NSMutableArray arrayWithCapacity: count ];

                for ( int i = 0; i < count && arg + 1 < argc; i ++ )
                {
                    ++ arg; /* Must be careful to leave 'arg' pointing at last "used" argument */
                    [ array addObject: [ NSString stringWithUTF8String: argv[ arg ] ] ];
                }

                params.coverArtNames = array;
            }

            else break; /* Assume a folder name */

            ++ arg;
        }

        /* If parameters are out of range or we've run out of arguments so no
         * folder filenames were supplied, complain.
         */

        if ( arg >= argc || params.maxImages < 1 || params.maxImages > 4 || params.showFolderInBackground > StyleShowFolderInBackgroundAlways )
        {
            printVersion();
            printHelp();
            return EX_USAGE;
        }

        /* Prerequisites */

        NSOperationQueue * queue           = [ [ NSOperationQueue  alloc ] init ];
        CGImageRef         backgroundImage = allocFolderIcon();

        globalSemaphoreInit();

        /* Process pathnames and add Grand Central Dispatch operations for each */

        for ( int i = arg; i < argc; i ++ )
        {
            NSString * fullPosixPath =
            [
                NSString stringWithUTF8String: argv[ i ]
            ];

            ConcurrentPathProcessor * processThisPath =
            [
                [ ConcurrentPathProcessor alloc ] initWithPath: fullPosixPath
                                                 andBackground: backgroundImage
                                                 andParameters: params
            ];

            NSArray * oneOp = [ NSArray arrayWithObject: processThisPath ];
            [ queue addOperations: oneOp waitUntilFinished: NO ];
        }

        [ queue waitUntilAllOperationsAreFinished ];

        CFRelease( backgroundImage );

    } // @autoreleasepool

    return ( globalErrorFlag == YES ) ? EXIT_FAILURE : EXIT_SUCCESS;
}

/******************************************************************************\
 * Print version and author to stdout,
\******************************************************************************/

static void printVersion (void)
{
    printf("%s version %s by %s\n", PROGRAM_STRING, VERSION_STRING, AUTHOR_STRING);
}

/******************************************************************************\
 * Print help string to stdout,
\******************************************************************************/

static void printHelp (void)
{
    printf( "Usage: %s [options] <folders>\n", PROGRAM_STRING );
    printf( "\n" );
    printf( "       Optional parameters are either:\n" );
    printf( "\n" );
    printf( "       [--slipcover <name>]\n" );
    printf( "                      Generate icons using the named SlipCover template - if\n" );
    printf( "                      specified, all other options are ignored and only the\n" );
    printf( "                      folder pathnames list is required; a copy of SlipCover\n" );
    printf( "                      must be installed and the template must exist\n");
    printf( "                      (default: use internal icon generator, not SlipCover)\n" );
    printf( "\n" );
    printf( "       Or alternatively:\n" );
    printf( "\n" );
    printf( "       [--crop]       Crop source images to squares\n" );
    printf( "                      (default: don't crop sources images)\n" );
    printf( "       [--border]     Add thin white border around thumbnails\n" );
    printf( "                      (default: don't add a border\n" );
    printf( "       [--shadow]     Add drop shadow behind thumbnails\n" );
    printf( "                      (default: don't add a drop shadow)\n" );
    printf( "       [--single]     Cover art single image mode\n" );
    printf( "                      (default: normal multi-image mode)\n" );
    printf( "       [--rotate]     Ignored in single image mode; else applies random\n" );
    printf( "                      rotation to thumbnails within icon\n" );
    printf( "                      (default: don't rotate thumbnails)\n" );
    printf( "       [--showfolder <n>]\n" );
    printf( "                      Ignored in single image mode; else number if images\n" );
    printf( "                      above which folder image is omitted\n" );
    printf( "                      (0 to 4, default: 2)\n" );
    printf( "       [--maximages <n>]\n" );
    printf( "                      Ignored in single image mode; else maximum number of\n" );
    printf( "                      thumbnails to include in each icon\n" );
    printf( "                      (1 to 4, default: 1)\n" );
    printf( "       [--coverart <size> <name, ...>\n" );
    printf( "                      Only used in single image mode; a list of 'size'\n" );
    printf( "                      items length giving the leafnames treated as cover art\n" );
    printf( "                      with no filename extensions or wildcards\n" );
    printf( "                      (default: cover, folder)\n");
    printf( "       [--labels]     Only used in single image mode; indicates that images\n");
    printf( "                      with Finder colour labels are treated as cover art too\n" );
    printf( "                      (default: labelled images are not cover art)\n" );
    printf( "\n" );
    printf( "       Final parameters must be:\n" );
    printf( "\n" );
    printf( "       <folder, ...>  Mandatory list of folder pathnames for processing\n" );
}
