/******************************************************************************\
 * addfoldericons: GlobalConstants.h
 *
 * Global application constant definitions. Other hard-coded constant values of
 * interest can be found in the library code.
 *
 * (C) Hipposoft 2009-2016 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import <Cocoa/Cocoa.h>

/* Some useful strings. The MASTER_VERSION... definitions are defined in the
 * project build settings under "Preprocessor Macros" and should be set up with
 * identical values in all configurations.
 */

#define PROGRAM_STRING "addfoldericons"
#define AUTHOR_STRING  "Andrew Hodgkinson"
#define VERSION_STRING "3.0.1.2016.03.21"

/* Standard square icon canvas edge length in 'non-retina' pixels */

#define CANVAS_SIZE 512

/* Avoid subdirectories which are package-like (e.g. applications)? */

#define SKIP_PACKAGES YES

/* Usually only 512x512 and 32x32 size icons are generated as this is visually
 * sufficient in the majority of cases and is much faster than generating every
 * possible size. Change from #undef to #define below if you want to also make
 * the 256x256, 128x128 and 16x16 size icons.
 */

#undef GENERATE_ALL_ICON_SIZES

/* Dump icon data (the original full size CGImage as a PNG) to a file for
 * debugging purposes? The filename is the folder name with
 * "__AddFolderIconsDumpedIcon__.png" concatenated on the end. If a file with
 * this name already exists it will be overwritten without warning.
 */

#undef DUMP_ICON_MASTER_IMAGE_TO_PNG_FILE

/* This global flag is set by the concurrent path processor if an error is
 * detected. Error messages are logged to the system console, printed to stderr
 * for direct command line users, and the global error flag is set so that the
 * application's overall return code can be set to EXIT_FAILURE rather than
 * EXIT_SUCCESS. Since several folder updates may have succeeded even if one
 * or more of the asynchronously processed folders failed, this "log the
 * details and return an overall general indication of success or failure"
 * approach is a decent balance of simplicity and information.
 */

Boolean globalErrorFlag; /* See main.m */
