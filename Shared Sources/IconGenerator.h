/******************************************************************************\
 * Utilities: IconGenerator.h
 *
 * Takes folders and creates a thumbnail icon that gives an idea of any images
 * contained inside that folder. Requires "Utilities: Miscellaneous" library.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import "Icons.h"
#import "Miscellaneous.h"
#import "IconParameters.h"

/* Fixed internal canvas size; border width around cropped images when at
 * their intermediate stage of being at full canvas size; blur radius and
 * offset for shadows; padding to go around the border - must give room for
 * the shadow and the worst-case extra extent of the outer edge of the shadow
 * due to +/- 0.075 radian (~4.5 degree) rotation. Values in pixels.
 *
 * If you change these, make sure you update "locations" below too.
 */

#define CANVAS_SIZE   512
#define THUMB_BORDER   20
#define BLUR_RADIUS    16
#define BLUR_OFFSET     8
#define ROTATION_PAD   40

/* Image search loop exit conditions (values are inclusive); zero equals
 * unlimited in either case (not recommended...).
 */

#define MAXIMUM_IMAGE_SIZE      67108864 /* 64MiB */
#define MAXIMUM_IMAGES_FOUND    5000
#define MAXIMUM_LOOP_TIME_TICKS CLOCKS_PER_SEC /* I.e. 1 second */

/******************************************************************************\
 * allocIconForFolder()
 *
 * Generate an icon for the folder identified by the given fully specified
 * POSIX-style pathname at CANVAS_SIZE x CANVAS_SIZE resolution (see the
 * "IconGenerator.h" header file). The caller is responsible for releasing the
 * returned object when it is no longer needed.
 *
 * The caller must ensure that a valid autorelease pool is present.
 *
 * In:  Fully specified POSIX-style path of folder of interest;
 *
 *      YES to generate an opaque background image (e.g. to use it as a
 *      thumbnail in a QuickLook generator, where thumbnails are always
 *      opaque) or NO to generate a transparent background image (e.g. to use
 *      as a preview in a QuickLook generator, or as a thumbanil in a Quick
 *      Look generator when the 'icon mode' options flag is clear);
 *
 *      YES to not enumerate contents of subdirectories if the subdirectory
 *      is package-like, else enumerate subdirectories regardless;
 *
 *      CGImageRef pointing to an icon to put underneath thumbnails if there
 *      are fewer than three layers making up the custom icon - usually this
 *      is obtained by a call to "allocFolderIcon" from outside the application
 *      main thread. Use NULL for no background image;
 *
 *      Pointer to an OSStatus updated on exit with 'noErr' if everything is
 *      OK, else an error code (see also 'errno' in such cases). This is
 *      required in addition to the function's return value to distinguish
 *      between NULL being returned because the folder contains no recognised
 *      images and thus needs no custom icon, or NULL being returned because an
 *      error was encountered while attempting to generate the custom icon;
 *
 *      Pointer to an initialised IconParameters instance describing the way
 *      in which to generate the icons.
 *
 * Out: CGImageRef pointing to thumbnail image or NULL if there is an error, or
 *      if there is no need to assign a custom icon (no images in folder). If
 *      non-NULL, caller must CFRelease() the memory when finished.
\******************************************************************************/

CGImageRef allocIconForFolder( NSString       * fullPosixPath,
                               BOOL             opaque,
                               BOOL             skipPackageLikeEntries,
                               CGImageRef       backgroundImage,
                               OSStatus       * thumbState,
                               IconParameters * params );
