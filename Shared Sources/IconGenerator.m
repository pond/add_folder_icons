/******************************************************************************\
 * Utilities: IconGenerator.m
 *
 * Takes folders and creates a thumbnail icon that gives an idea of any images
 * contained inside that folder. Requires "Utilities: Miscellaneous" library.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import "IconGenerator.h"
#import "CaseGenerator.h"
#import "GlobalSemaphore.h"

/* Declare local functions */

static NSMutableArray * allocFoundImagePathArray( NSString       * fullPosixPath,
                                                  BOOL             skipPackageLikeEntries,
                                                  OSStatus       * thumbState,
                                                  IconParameters * params );

static BOOL             paintImage              ( CFStringRef      fullPosixPath,
                                                  CGRect           rect,
                                                  CGContextRef     context,
                                                  BOOL             cropImages );

static CGImageRef       allocCustomIcon         ( NSMutableArray * chosenImages,
                                                  CGImageRef       backgroundImage,
                                                  BOOL             opaque,
                                                  OSStatus       * thumbState,
                                                  IconParameters * params );

static CGImageRef       allocSlipCoverIcon      ( NSMutableArray * chosenImages,
                                                  OSStatus       * thumbState,
                                                  IconParameters * params );

/* Pre-computed locations inside a CANVAS_SIZE square canvas for cropped
 * thumbnail icons for when there are between 1 and 4 icons available. See
 * "IconGenerator.h" for CANVAS_SIZE and other relevant definitions.
 *
 * The compuation takes the worst case of an icon with no border, shadow or
 * rotation with image cropping enabled, so the painted image fills the whole
 * canvas prior to scaling. The width, height and origins are calculated on
 * that basis. At run-time, adjustments are made to these values when there
 * is more than one thumbnail being included, which bring thumbnails closer
 * together when shadows or rotation are included as the image in such cases
 * is not filling the canvas and the gaps start to look too large. With
 * rotation and shadows, a bit of overlap looks good.
 *
 * Ordering is important to make sure that when one icon overlaps another,
 * it will overlap with its drop shadow part hanging above the next icon. So,
 * start plotting in the bottom right corner and work anti-clockwise.
 */

static CGRect locations[ 4 ][ 4 ] =
{
    {
        { .origin.x = 112, .origin.y =  76, .size.width = 288, .size.height = 288 }
    },

    {
        { .origin.x = 264, .origin.y = 112, .size.width = 216, .size.height = 216 },
        { .origin.x =  32, .origin.y = 112, .size.width = 216, .size.height = 216 }
    },

    {
        { .origin.x = 264, .origin.y =   0, .size.width = 248, .size.height = 248 },
        { .origin.x =   0, .origin.y =   0, .size.width = 248, .size.height = 248 },
        { .origin.x = 132, .origin.y = 264, .size.width = 248, .size.height = 248 }
    },

    {
        { .origin.x = 264, .origin.y =   0, .size.width = 248, .size.height = 248 },
        { .origin.x =   0, .origin.y =   0, .size.width = 248, .size.height = 248 },
        { .origin.x = 264, .origin.y = 264, .size.width = 248, .size.height = 248 },
        { .origin.x =   0, .origin.y = 264, .size.width = 248, .size.height = 248 }
    }
};

/******************************************************************************\
 * allocFoundImagePathArray()
 *
 * Based on given folder and icon generation parameters, search the folder for
 * suitable images to use as part of icon generation and return a pointer to a
 * mutable array containing full POSIX paths (as NSString pointers) of the
 * found image(s). The caller gets ownership of the array and must eventually
 * discard it with a call to '-release'.
 *
 * Images may be enumerated from the given directory freely, or may be
 * constrainted by some of the settings in the given icon parameters structure.
 * The found images are always narrowed down to a collection the maximum size
 * of which is dictated by the icon parameters' "maxImages" property. The order
 * of choice will always be random even if there were less found images than
 * this maximum, so unless there is only one found image, the results may be
 * different from call to call, even if all input parameters are equal. This
 * can be prevented by setting with icon parameters' "previewMode" flag, which
 * if YES causes the requested number of images to be drawn sequentially from
 * the found pool, from first found upwards in order of enumeration.
 *
 * Returns 'nil' if anything goes wrong (see also parameter 'thumbState') or
 * if no images are found, else an array with at least one image inside.
 *
 * This function allows re-entrant callers from multiple threads using
 * independent execution contexts, as it protects thread-sensitive sections
 * using the global semaphore.
 *
 * The caller must ensure that an autorelease pool is available.
 *
 * In:  Fully specified POSIX-style path of folder of interest;
 *
 *      YES to not enumerate contents of subdirectories if the subdirectory
 *      is package-like, else enumerate subdirectories regardless;
 *
 *      Pointer to an OSStatus updated on exit with 'noErr' if everything is
 *      OK, else an error code (see also 'errno' in such cases). This is
 *      required in addition to the function's return value to distinguish
 *      between NULL being returned because the folder contains no recognised
 *      images and thus needs no custom icon, or NULL being returned because an
 *      error was encountered while attempting to generate the custom icon;
 *
 *      Pointer to an initialised IconParameters instance describing the way
 *      in which to generate the icons, which in turn influences the image
 *      search (e.g. for multiple images, or a single cover art image).
 *
 * Out: Pointer to a caller-owned NSMutableArray containing the .
\******************************************************************************/

static NSMutableArray * allocFoundImagePathArray( NSString       * fullPosixPath,
                                                  BOOL             skipPackageLikeEntries,
                                                  OSStatus       * thumbState,
                                                  IconParameters * params )
{
    NSFileManager     * fileMgr      = [ [ NSFileManager alloc ] init ]; /* http://developer.apple.com/mac/library/documentation/Cocoa/Reference/Foundation/Classes/NSFileManager_Class/Reference/Reference.html */
    NSString          * enumPath     = fullPosixPath;
    NSString          * currFile;
    NSMutableArray    * images       = [ NSMutableArray arrayWithCapacity: 0 ];
    NSMutableArray    * chosenImages = nil;
    BOOL                failed       = NO;
    errno                            = 0;

    /* We consider ourselves in Single Image Mode if using that flag explicitly
     * or if using SlipCover code for icon generation.
     */
     
    BOOL singleImageMode = ( params.singleImageMode == YES || params.slipCoverCase != nil ) ? YES : NO;

    /* Directory enumeration is needed in multiple image mode and may be needed
     * in single image mode; besides, this gives us a quick way to discover if
     * the path to the folder seems to be invalid.
     */

    NSDirectoryEnumerator * dirEnum  = [ fileMgr enumeratorAtPath: enumPath ];
    NSDictionary          * dirAttrs = [ dirEnum directoryAttributes ];

    if ( ! dirAttrs ) /* Yes - this is ugly, but at least it's effective */
    {
        errno       = ENOENT;
        *thumbState = kPOSIXErrorBase + errno;
        require ( dirAttrs, nothingToDo );
    }

    /* Look for image files. The search is exited early if a certain number
     * of images have been found or the loop has been running for too long in
     * multiple image mode.
     */

    if ( singleImageMode )
    {
        /* Although we got hold of a directory enumerator earlier, we get
         * a new one here as we're only interested in finding the right
         * label colour or files with the right start to their names.
         * Subdirectories are explicitly NOT scanned.
         */

        NSString * found         = nil;
        NSURL    * enumPathAsURL = [ [ NSURL alloc ] initFileURLWithPath: enumPath
                                                             isDirectory: YES ];

        dirEnum = [ fileMgr enumeratorAtURL: enumPathAsURL
                 includingPropertiesForKeys: @[
                                               NSURLLabelColorKey,
                                               NSURLIsDirectoryKey,
                                               NSURLIsRegularFileKey
                                             ]
                                    options: NSDirectoryEnumerationSkipsHiddenFiles
                               errorHandler: nil ];

        @try
        {
            /* Semaphore use rationale - see multiple image code below */

            globalSemaphoreClaim();

            for ( NSURL * theURL in dirEnum )
            {
                NSString * fullPath = [ theURL path ];

                /* Extract the cached directory and color label data */

                NSError  * resourceError = nil;
                NSNumber * isDirectory;

                [ theURL getResourceValue: &isDirectory
                                   forKey: NSURLIsDirectoryKey
                                    error: &resourceError ];

                NSNumber * isRegularFile;

                [ theURL getResourceValue: &isRegularFile
                                   forKey: NSURLIsRegularFileKey
                                    error: &resourceError ];

                NSColor * labelColour;

                [ theURL getResourceValue: &labelColour
                                   forKey: NSURLLabelColorKey
                                    error: &resourceError ];

                /* Assuming no errors, skip subdirectories and look for
                 * labelled, "cover" or "folder" leafname images.
                 *
                 * MAXIMUM_IMAGE_SIZE is not obeyed as we're looking for
                 * specific leafnames or a colour label in single image
                 * mode and the implication is that the user wants us to
                 * use that image regardless. This is quite different
                 * from a generic directory scan.
                 */

                if ( resourceError == nil )
                {
                    if ( [ isDirectory boolValue ] == YES )
                    {
                        [ dirEnum skipDescendants ];
                    }
                    else if ( [ isRegularFile boolValue ] == YES && isImageFile( fullPath ) == YES )
                    {
                        NSString * leaf = [ [ fullPath lastPathComponent ] stringByDeletingPathExtension ];

                        if ( labelColour != nil && params.useColourLabels )
                        {
                            found = fullPath;
                            break;
                        }

                        NSUInteger foundIndex =
                        [
                            params.coverArtNames indexOfObjectWithOptions: NSEnumerationConcurrent
                                                              passingTest: ^BOOL ( NSString * obj, NSUInteger idx, BOOL * stop )
                            {
                                if ( [ obj localizedCaseInsensitiveCompare: leaf ] == NSOrderedSame )
                                {
                                    *stop = YES;
                                    return YES;
                                }
                                else
                                {
                                    return NO;
                                }
                            }
                        ];

                        if ( foundIndex != NSNotFound )
                        {
                            found = fullPath;
                            break;
                        }
                    }
                }
            }
        }
        @catch ( id ignored )
        {
            *thumbState = kPOSIXErrorBase + errno; /* (Just in case errno was updated) */
            failed      = YES;
        }
        @finally
        {
            globalSemaphoreRelease();
        }

        if ( found ) [ images addObject: found ];
    }
    else /* "if ( singleImageMode )" */
    {
        srandomdev(); /* Randomise the random number generator */

        /* Directory scanning is timed to avoid excessively long / deep folder
         * recursion holding up process completion. To keep this timer sane, only
         * one scan is run at a time. This helps avoid excessive filesystem
         * thrashing in passing (i.e. there's a very good chance that the code
         * will complete more quickly when this section runs in series rather
         * than if it attempts to run in parallel).
         */

        @try
        {
            globalSemaphoreClaim();
            clock_t startTime = clock();

            while ( ( currFile = [ dirEnum nextObject ] ) )
            {
                NSDictionary * currAttrs = [ dirEnum fileAttributes ];
                if ( ! currAttrs ) continue;

                NSString * fileType = currAttrs[ NSFileType ];
                NSString * fullPath = [
                    enumPath stringByAppendingPathComponent: currFile
                ];

                /* Only interested in regular files or directories, nothing more. Skip
                 * directories that appear to have filename extensions because
                 * they're probably packaged formats of some kind (e.g. applications).
                 */

                if ( [ fileType isEqualToString: NSFileTypeRegular ] )
                {
                    if ( isImageFile( fullPath ) == YES )
                    {
                        #ifdef MAXIMUM_IMAGE_SIZE
                        {
                            NSNumber * size = currAttrs[ NSFileSize ];
                            if ( [ size unsignedLongLongValue ] > MAXIMUM_IMAGE_SIZE ) continue;
                        }
                        #endif

                        [ images addObject: fullPath ];

                        /* Once we have enough images, bail */

                        if (
                               MAXIMUM_IMAGES_FOUND != 0 &&
                               [ images count ] >= MAXIMUM_IMAGES_FOUND
                           )
                           break;
                    }
                }
                else if (
                               skipPackageLikeEntries
                            && [ fileType isEqualToString: NSFileTypeDirectory ]
                            && isLikeAPackage( fullPath )
                        )
                {
                    [ dirEnum skipDescendents ];
                }

                /* If we've run for too long, bail */

                if (
                       MAXIMUM_LOOP_TIME_TICKS != 0 &&
                       clock() - startTime >= MAXIMUM_LOOP_TIME_TICKS
                   )
                   break;
            }
        }
        @catch ( id ignored )
        {
            *thumbState = kPOSIXErrorBase + errno; /* (Just in case errno was updated) */
            failed      = YES;
        }
        @finally
        {
            globalSemaphoreRelease();
        }

    } /* "else" of "if ( singleImageMode )" */

    /* If there are no images, exit; the standard folder icon will be used */

    if ( [ images count ] == 0 )
    {
        if ( ! failed ) *thumbState = noErr;
        require( false, nothingToDo );
    }

    /* Otherwise, choose up to four images at random */

    NSUInteger maxImages = params.maxImages;

    if      ( maxImages < 1 ) maxImages = 1;
    else if ( maxImages > 4 ) maxImages = 4;

    chosenImages = [ [ NSMutableArray alloc ] initWithCapacity: 0 ];

    while ( [ images count ] > 0 && [ chosenImages count ] < maxImages )
    {
        /* Using random() in this way is fine - unlike rand(), all bits are
         * considered sufficiently random in the generated integer.
         */

        NSUInteger randomIndex;

        if ( params.previewMode == YES ) randomIndex = 0;
        else                             randomIndex = random() % [ images count ];

        [ chosenImages addObject: images[ randomIndex ] ];
        [ images removeObjectAtIndex: randomIndex ];
    }

nothingToDo:

    ;
    return chosenImages;
}

/******************************************************************************\
 * paintImage()
 *
 * Paint an image found at the given fully specified POSIX-style file path
 * into the given rectangle under the given context. The image is cropped to
 * a square before being painted; if the target rectangle is not also square
 * the image will be distorted when painted.
 *
 * In:  Full POSIX path of the image to load, crop to 1:1 aspect and paint,
 *      or scaled to fit without distortion if 'cropImages' is NO (see below);
 *
 *      Rectangle into which the cropped image should be painted, distorting
 *      its aspect ratio to fit if necessary, or fitted into if 'cropImages'
 *      is NO (see below);
 *
 *      Graphics context for the painting operation;
 *
 *      YES to crop images to squares, NO to preserve aspect ratio.
 *
 * Out: YES if successful, NO if failed.
\******************************************************************************/

static BOOL paintImage( CFStringRef  fullPosixPath,
                        CGRect       rect,
                        CGContextRef context,
                        BOOL         cropImages )
{
    BOOL   success = YES;
    size_t width, height;

    /* Turn the POSIX path into a URL, the URL into an image source and the
     * image source into an image object based on index 0 from the source
     * file (i.e. for multi-page TIFFs, Icon files etc., take the first of
     * however many sub-images are contained within).
     */

    CGImageSourceRef imageSource = NULL;
    CGImageRef       image       = NULL;
    CFURLRef         url         = CFURLCreateWithFileSystemPath
    (
        kCFAllocatorDefault,
        fullPosixPath,
        kCFURLPOSIXPathStyle,
        false
    );

    if ( url         ) imageSource = CGImageSourceCreateWithURL( url, NULL );
    if ( imageSource ) image       = CGImageSourceCreateImageAtIndex( imageSource, 0, NULL );
    if ( image       )
    {
        width  = CGImageGetWidth  ( image );
        height = CGImageGetHeight ( image );

        /* EXIF rotation is in the metadata and the above ignores it, so there
         * is more work to do still. If we used NSImage this would all go away,
         * but tests of early NSImage-based code showed it was very much slower
         * than CoreGraphics. Since calculating the correct top-or-middle
         * cropping rectangles and persuading all the coordinate space
         * transformations to work properly would be particularly thorny and
         * open to mistakes for edge case image types, we simply recreate a new
         * image in the transformed orientation at full size and continue to
         * work with that later in the code.
         *
         * Allocation failures are ignored as correct orientation inside the
         * thumbnail is not considered critical.
         *
         * The code is derived from:
         *
         *   http://developer.apple.com/library/mac/#samplecode/MyPhoto/Listings/Step8_ImageView_m.html
         *   http://developer.apple.com/library/mac/#samplecode/CGRotation/Introduction/Intro.html
         */
        
        NSDictionary * metadata = (__bridge_transfer  NSDictionary * /* Toll-free bridge */ )
                                  CGImageSourceCopyPropertiesAtIndex( imageSource, 0, NULL );

        if ( metadata )
        {
            NSNumber * val;
            CGFloat    dpi, xdpi, ydpi;
            int        orientation;

            val  = metadata[ ( id ) kCGImagePropertyDPIWidth ];
            dpi  = [ val floatValue ];
            xdpi = ( dpi == 0 ) ? 72.0 : dpi;

            val  = metadata[ ( id ) kCGImagePropertyDPIHeight ];
            dpi  = [ val floatValue ];
            ydpi = ( dpi == 0 ) ? 72.0 : dpi;

            val  = metadata[ ( id ) kCGImagePropertyOrientation ];
            orientation = [ val intValue ];
            if ( orientation < 1 || orientation > 8 ) orientation = 1;

            CGFloat x = ( ydpi > xdpi ) ? ydpi / xdpi : 1;
            CGFloat y = ( xdpi > ydpi ) ? xdpi / ydpi : 1;

            if ( x != 1.0 || y != 1.0 || orientation != 1 )
            {
                CGFloat w = x * width;
                CGFloat h = y * height;
                
                CGAffineTransform ctms[ 8 ] =
                {
                    {  x,  0,  0,  y, 0, 0 }, // 1 = row 0 top, col 0 lhs = normal
                    { -x,  0,  0,  y, w, 0 }, // 2 = row 0 top, col 0 rhs = flip horizontal
                    { -x,  0,  0, -y, w, h }, // 3 = row 0 bot, col 0 rhs = rotate 180
                    {  x,  0,  0, -y, 0, h }, // 4 = row 0 bot, col 0 lhs = flip vertical
                    {  0, -x, -y,  0, h, w }, // 5 = row 0 lhs, col 0 top = rot -90, flip vert
                    {  0, -x,  y,  0, 0, w }, // 6 = row 0 rhs, col 0 top = rot 90
                    {  0,  x,  y,  0, 0, 0 }, // 7 = row 0 rhs, col 0 bot = rot 90, flip vert
                    {  0,  x, -y,  0, h, 0 }  // 8 = row 0 lhs, col 0 bot = rotate -90
                };

                /* Create a context big enough to hold the image's actual pixel
                 * size, regardless of pixel aspect ratio, but accounting for a
                 * possible rotation at ±90 degrees (orientations 5-8).
                 */

                CGContextRef transformationContext;
                size_t contextWidth, contextHeight;

                if ( orientation <= 4 ) contextWidth = width, contextHeight = height;
                else                    contextWidth = height, contextHeight = width;

                transformationContext = CGBitmapContextCreate
                (
                    NULL,
                    contextWidth,
                    contextHeight,
                    8,                /* Bits per component */
                    contextWidth * 4, /* Bytes per row      */
                    CGImageGetColorSpace( image ),
                    kCGImageAlphaPremultipliedFirst
                );

                if ( transformationContext != NULL )
                {
                    CGContextConcatCTM( transformationContext, ctms[ orientation - 1 ] );
                    CGContextDrawImage( transformationContext, CGRectMake( 0, 0, width, height ), image );

                    /* Release the old image first to avoid accumulating lots
                     * of copies in RAM. Worse case, we end up with a NULL
                     * 'image' and no thumbnail plotted for this image.
                     */

                    CFRelease( image );
                    image = CGBitmapContextCreateImage( transformationContext );
                    CFRelease( transformationContext );

                    if ( image )
                    {
                        width  = CGImageGetWidth  ( image );
                        height = CGImageGetHeight ( image );
                    }
                }
            }
        }

        if ( cropImages && image )
        {
            /* Create a sub-image based on a square crop of the original. If
             * the image is wider than tall (landscape), use a center crop.
             * If the image is taller than wide (portrait), use the top part
             * of it - on average this works well for pictures of people.
             */

            BOOL       isSquare = NO;
            CGRect     cropRect;
            CGImageRef croppedImage;

            if      ( width > height ) cropRect = CGRectMake( ( width - height ) / 2, 0, height, height );
            else if ( height > width ) cropRect = CGRectMake( 0, 0, width, width ); /* Image *top* left is (0,0) */
            else                       isSquare = YES;

            if ( isSquare == NO )
            {
                croppedImage = CGImageCreateWithImageInRect( image, cropRect );
                CFRelease( image );
                image = croppedImage;
            }
        }
        else
        {
            /* Adjust the plotting rectangle to avoid image cropping */

            CGFloat rectWidth  = rect.size.width;
            CGFloat rectHeight = rect.size.height;

            if ( width > height )
            {
                CGFloat scaledHeight = height * ( rectWidth / width );
                CGFloat yOffset      = ( rectHeight - scaledHeight ) / 2;

                rect.origin.y    += yOffset;
                rect.size.height  = scaledHeight;
            }
            else
            {
                CGFloat scaledWidth = width * ( rectHeight / height );
                CGFloat xOffset     = ( rectWidth - scaledWidth ) / 2;

                rect.origin.x   += xOffset;
                rect.size.width  = scaledWidth;
            }
        }
    }

    /* Check 'image' again in case cropping was attempted but failed */

    if ( image ) CGContextDrawImage( context, rect, image );

    /* Make sure everything is released */

    if ( image       ) CFRelease( image       ); else success = NO;
    if ( imageSource ) CFRelease( imageSource ); else success = NO;
    if ( url         ) CFRelease( url         ); else success = NO;

    return success;
}

/******************************************************************************\
 * allocCustomIcon()
 *
 * Generate a folder icon with an array of images to be included as thumbnails,
 * at CANVAS_SIZE x CANVAS_SIZE resolution (see the "IconGenerator.h" header
 * file), using custom icon generation parameters. The caller is responsible
 * for releasing the returned object when it is no longer needed.
 *
 * This function allows re-entrant callers from multiple threads using
 * independent execution contexts.
 *
 * The caller must ensure that an autorelease pool is available.
 *
 * In:  Pointer to an NSMutableArray of NSString pointers with each string
 *      giving the full POSIX path of an image to be included within the icon;
 *      at least one image must be present; if there are more than needed, then
 *      items at higher indicies will be ignored (e.g. if you provide four
 *      images but the icon parameters specify single image mode, then only the
 *      first item in the array will be used) - this array can be obtained from
 *      a call to "allocFoundImagePathArray";
 *
 *      CGImageRef pointing to an icon to put underneath thumbnails if icon
 *      parameters say that this should be used - usually this is obtained by
 *      a call to "allocFolderIcon" from outside the application main thread.
 *      Use NULL for no background image;
 *
 *      YES to generate an opaque background image (e.g. to use it as a
 *      thumbnail in a QuickLook generator, where thumbnails are always
 *      opaque) or NO to generate a transparent background image (e.g. to use
 *      as a preview in a QuickLook generator, or as a thumbanil in a Quick
 *      Look generator when the 'icon mode' options flag is clear);
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

static CGImageRef allocCustomIcon( NSMutableArray * chosenImages,
                                   CGImageRef       backgroundImage,
                                   BOOL             opaque,
                                   OSStatus       * thumbState,
                                   IconParameters * params )
{
    CGImageRef finalImage = NULL;

    /* We consider ourselves in Single Image Mode if using that flag explicitly
     * or if using SlipCover code for icon generation.
     */
     
    BOOL singleImageMode = ( params.singleImageMode == YES || params.slipCoverCase != nil ) ? YES : NO;

    /**************************************************************************\
     * Create layers representing thumbnails of the images
    \**************************************************************************/

    /* Get a graphics context for painting things. This is constructed as a
     * bespoke bitmap context rather than using the one we could obtain from
     * Quick Look because it opens up more possibilities later (there is
     * direct control over alpha channel provision, though transparency is
     * extremely problematic under Quick Look - most of the time, you don't
     * get it, regardless of context).
     */

    NSUInteger      canvasSize = dpiValue( CANVAS_SIZE );
    CGSize          pixelSize  = CGSizeMake(       canvasSize, canvasSize );
    CGRect          pixelRect  = CGRectMake( 0, 0, canvasSize, canvasSize );
    CGContextRef    context    = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    if ( colorSpace )
    {
        context = CGBitmapContextCreate
        (
            NULL,           /* OS X 10.3 or later => CG allocates for us */
            canvasSize,
            canvasSize,
            8,              /* Bits per component */
            canvasSize * 4, /* Bytes per row      */
            colorSpace,
            kCGImageAlphaPremultipliedFirst
        );

        CGColorSpaceRelease( colorSpace );
    }

    if ( ! context ) return nil; // Note early exit!

    CGContextSetShouldAntialias      ( context, true                 );
    CGContextSetInterpolationQuality ( context, kCGInterpolationHigh );

    /* Create layers into which thumbnails will be drawn. These will be
     * scaled down again when drawn into the final icon and will use anti-
     * aliasing then, but we need to keep high quality settings on the
     * layers to make sure that the rotated edges look good.
     */

    NSUInteger        count  = [ chosenImages count ];
    CFMutableArrayRef layers = CFArrayCreateMutable
    (
        kCFAllocatorDefault,
        count,
        NULL
    );

    for ( size_t index = 0; index < count; index ++ )
    {
        /* Ensure the array actually contains 'count' NULL items. Within the
         * Grand Central processing loop below, used layers are written into
         * the array at specific indices. Doing this means that the array can
         * be written to by concurrent processes without locking. If we just
         * tried to extend the array within the processing loop then we'd have
         * to serialise the operation (as two threads attempting to extend the
         * same array simultaneously could just corrupt the data structure).
         */

        CFArrayAppendValue( layers, NULL );
    }

    dispatch_apply
    (
        count,
        dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ),
        ^( size_t index )
        {
            NSString * currFile = chosenImages[ ( NSUInteger ) index ];

            CGLayerRef   layer    = CGLayerCreateWithContext( context, pixelSize, NULL );
            CGContextRef layerCtx = CGLayerGetContext( layer );

            CGContextSetShouldAntialias      ( layerCtx, true                 );
            CGContextSetInterpolationQuality ( layerCtx, kCGInterpolationHigh );

            /* To start with, set a thumbnail size to match the entire canvas.
             * As things like shadows, rotation and border get applied, reduce
             * these values as appropriate to make sure that the final scaled
             * thumbnail fits within the canvas, even with any effects applied.
             */

            CGFloat thumbSize = canvasSize;

            /* Paint in a transparency layer using a shadow offset to the bottom
             * and right by BLUR_OFFSET with a radius of BLUR_RADIUS.
             */

            CGContextBeginTransparencyLayer( layerCtx, NULL );
            CGContextTranslateCTM( layerCtx, canvasSize / 2, canvasSize / 2 );

            if ( params.rotate == YES )
            {
                CGContextRotateCTM( layerCtx, ( ( random() % 300 ) - 150 ) / 2000.0 );

                thumbSize -= dpiValue( ROTATION_PAD );
            }

            if ( params.shadow == YES )
            {
                /* Go for a symmetrical border-like drop shadow in multi-image
                 * mode, else for the larger icon-filling single-image mode,
                 * use a drop shadow modelled on the Finder's typical shadow
                 * style - offset downwards.
                 */
            
                if ( singleImageMode == NO )
                {
                    CGContextSetShadow
                    (
                        layerCtx,
                        CGSizeMake( 0, dpiValue( -BLUR_OFFSET ) ),
                        dpiValue( BLUR_RADIUS )
                    );

                    /* "* 2" on the blur offset is basically a fudge factor.
                     * AFAICS just adding the radius and offset should give a
                     * correct adjustment to make room for the shadow but in
                     * practice it gets cut off at the bottom unless a bit of
                     * extra room is provided.
                     */

                    thumbSize -= dpiValue( BLUR_RADIUS + BLUR_OFFSET * 2 );
                }
                else
                {
                    /* The default shadow colour is much lighter than shown in e.g.
                     * the Finder's thumbnails for image files (probably because of
                     * colour space issues), so darken it by specifying an exact
                     * colour in generic RGB space (noting that we used device RGB
                     * when the outer graphics bitmap context was created).
                     */

                    CGColorRef c = CGColorCreateGenericRGB( 0.3, 0.3, 0.3, 1 );

                    if ( c )
                    {
                        CGContextSetShadowWithColor
                        (
                            layerCtx,
                            CGSizeMake( 0, dpiValue( -( BLUR_OFFSET / 2 ) ) ),
                            dpiValue( ( BLUR_RADIUS / 3 ) * ( BLUR_OFFSET / 2 ) ),
                            c
                        );

                        CGColorRelease( c );

                        /* Unlike the case above, here just adding the blur
                         * radius and offset is sufficient for some reason.
                         */

                        thumbSize -= dpiValue( BLUR_RADIUS * ( BLUR_OFFSET / 2 ) + ( BLUR_OFFSET / 2 ) );
                    }
                }
            }

            /* Hide the border in single image mode or if borders are disabled,
             * putting the shadow beneath the image.
             */

            if ( params.border == YES )
            {
                CGFloat borderSize = thumbSize;
                thumbSize -= dpiValue( THUMB_BORDER * 2 );

                CGContextSetRGBFillColor( layerCtx, 1, 1, 1, 1.0 );
                CGContextFillRect
                (
                    layerCtx,
                    CGRectMake
                    (
                        -borderSize / 2,
                        -borderSize / 2,
                        borderSize,
                        borderSize
                    )
                );

                /* Don't want another shadow under the inset image so turn off
                 * shadows before calling the painting routine.
                 */

                CGContextSetShadowWithColor
                (
                    layerCtx,
                    CGSizeMake( 0, 0 ),
                    0,
                    NULL /* NULL colour => disable shadows */
                );
            }

            BOOL success = paintImage
            (
                ( __bridge CFStringRef ) currFile, /* Toll-free bridge */
                CGRectMake
                (
                    -thumbSize / 2,
                    -thumbSize / 2,
                    thumbSize,
                    thumbSize
                ),
                layerCtx,
                params.crop
            );

            CGContextEndTransparencyLayer( layerCtx );

            if ( success ) CFArraySetValueAtIndex( layers, index, layer );
            else CGLayerRelease( layer );

        } /* End of Grand Central dispatch block      */
    );    /* End of Grand Central dispatch_apply call */

    /**************************************************************************\
     * Construct the final thumbnail
    \**************************************************************************/

    /* Count the number of layers which were actually used. If non-zero,
     * iterate through any thumbnails, painting them into the right location
     * on the final canvas, freeing layers as we go.
     */

    CFIndex layerCount = 0;

    for ( size_t index = 0; index < count; index ++ )
    {
        if ( CFArrayGetValueAtIndex( layers, index ) != NULL ) layerCount ++;
    }

    if ( layerCount > 0 )
    {
        CGContextBeginTransparencyLayer( context, NULL );

        /* Quick Look enforces an opaque thumbnail. If we use a clear
         * background then it'll (bizarrely) work fine if looking at the
         * index sheet for a collection of folders selected at once for
         * Quick Look, but single folders and in-Finder icons are all
         * opaque; some with the 'page curl' effect, some without.
         *
         * Callers can anticipate this and ask for an opaque thumbnail
         * if Quick Look is being invoked in 'for Finder-style file icon'
         * mode.
         */

        if ( opaque )
        {
            if ( layerCount < 3 ) CGContextSetRGBFillColor( context, 1.00, 1.00, 1.00, 1.0 );
            else                  CGContextSetRGBFillColor( context, 0.62, 0.77, 0.85, 1.0 );

            CGContextFillRect( context, pixelRect );
        }
        else
        {
            CGContextClearRect( context, pixelRect );
        }

        /* For one or two thumbnails only when in multiple image mode, plot
         * the standard folder icon underneath.
         */

        if ( singleImageMode == NO && layerCount <= params.showFolderInBackground && backgroundImage )
        {
            CGContextDrawImage( context, pixelRect, backgroundImage );
        }

        /* Now plot the thumbnails themselves */

        if ( params.singleImageMode )
        {
            CGLayerRef layer = ( CGLayerRef ) CFArrayGetValueAtIndex( layers, 0 );

            CGContextDrawLayerInRect
            (
                context,
                CGRectMake( 0, 0, canvasSize, canvasSize ),
                layer
            );

            CGLayerRelease( layer );
        }
        else
        {
            /* Adjust plot positions and sizes according to the various
             * effects that might be in use.
             */

            CGFloat adjustSize             = 0;
            CGRect  adjustedLocations[ 4 ] =
            {
                locations[ layerCount - 1 ][ 0 ],
                locations[ layerCount - 1 ][ 1 ],
                locations[ layerCount - 1 ][ 2 ],
                locations[ layerCount - 1 ][ 3 ]
            };

            if ( params.shadow == YES ) adjustSize += ( BLUR_RADIUS + BLUR_OFFSET * 2 );
            if ( params.rotate == YES ) adjustSize += ROTATION_PAD;

            if ( adjustSize > 0 )
            {
                adjustSize /= 3;   /* "Looks about right" adjustment that works
                                    * even though thumbnail scaling sizes in
                                    * 'adjustedLocations' vary according to the
                                    * number of images.
                                    */

                switch ( layerCount )
                {
                    case 2:
                    {
                        adjustedLocations[ 0 ].origin.x    -= adjustSize;
                        adjustedLocations[ 0 ].origin.y    -= adjustSize / 2;
                        adjustedLocations[ 0 ].size.width  += adjustSize;
                        adjustedLocations[ 0 ].size.height += adjustSize;

                        adjustedLocations[ 1 ].origin.y    -= adjustSize / 2;
                        adjustedLocations[ 1 ].size.width  += adjustSize;
                        adjustedLocations[ 1 ].size.height += adjustSize;
                    }
                    break;
                    
                    case 3:
                    {
                        adjustedLocations[ 0 ].origin.x    -= adjustSize;
                        adjustedLocations[ 0 ].size.width  += adjustSize;
                        adjustedLocations[ 0 ].size.height += adjustSize;

                        adjustedLocations[ 1 ].size.width  += adjustSize;
                        adjustedLocations[ 1 ].size.height += adjustSize;

                        adjustedLocations[ 2 ].origin.x    -= adjustSize / 2;
                        adjustedLocations[ 2 ].origin.y    -= adjustSize;
                        adjustedLocations[ 2 ].size.width  += adjustSize;
                        adjustedLocations[ 2 ].size.height += adjustSize;
                    }
                    break;
                    
                    case 4:
                    {
                        adjustedLocations[ 0 ].origin.x    -= adjustSize;
                        adjustedLocations[ 0 ].size.width  += adjustSize;
                        adjustedLocations[ 0 ].size.height += adjustSize;

                        adjustedLocations[ 1 ].size.width  += adjustSize;
                        adjustedLocations[ 1 ].size.height += adjustSize;

                        adjustedLocations[ 2 ].origin.x    -= adjustSize;
                        adjustedLocations[ 2 ].origin.y    -= adjustSize;
                        adjustedLocations[ 2 ].size.width  += adjustSize;
                        adjustedLocations[ 2 ].size.height += adjustSize;

                        adjustedLocations[ 3 ].origin.y    -= adjustSize;
                        adjustedLocations[ 3 ].size.width  += adjustSize;
                        adjustedLocations[ 3 ].size.height += adjustSize;
                    }
                    break;
                }                
            }

            /* Plot in the adjusted rectangles */

            for ( CFIndex index = 0; index < layerCount; index ++ )
            {
                CGLayerRef layer    = ( CGLayerRef ) CFArrayGetValueAtIndex( layers, index );
                CGRect     thisRect = adjustedLocations[ index ];
                CGRect     dpiRect  = CGRectMake(
                                                    dpiValue( thisRect.origin.x    ),
                                                    dpiValue( thisRect.origin.y    ),
                                                    dpiValue( thisRect.size.width  ),
                                                    dpiValue( thisRect.size.height )
                                                );

                CGContextDrawLayerInRect( context, dpiRect, layer );
                CGLayerRelease( layer );
            }
        }

        CGContextEndTransparencyLayer( context );

        /* Flush out any pending graphics operations and set the thumbnail
         * response for this generator, or set a custom icon for the folder.
         */

        CGContextFlush( context );
        finalImage = CGBitmapContextCreateImage( context );

        /* Success? */

        if ( finalImage ) *thumbState = noErr;
    }

    /**************************************************************************\
     * Tidy up
    \**************************************************************************/

    CFRelease( layers  );
    CFRelease( context );

    return finalImage;

}

/******************************************************************************\
 * allocSlipCoverIcon()
 *
 * Generate a folder icon using SlipCover code at CANVAS_SIZE x CANVAS_SIZE
 * resolution (see the "IconGenerator.h" header file). The caller is
 * responsible for releasing the returned object when it is no longer needed.
 *
 * This function allows re-entrant callers from multiple threads using
 * independent execution contexts.
 *
 * The caller must ensure that an autorelease pool is available.
 *
 * In:  Pointer to an NSMutableArray of NSString pointers with each string
 *      giving the full POSIX path of an image to be included within the icon;
 *      at least one image must be present; only one is needed, so if there is
 *      more than one path present, only the first (index 0) will be used;
 *
 *      Pointer to an OSStatus updated on exit with 'noErr' if everything is
 *      OK, else an error code (see also 'errno' in such cases). This is
 *      required in addition to the function's return value to distinguish
 *      between NULL being returned because the folder contains no recognised
 *      images and thus needs no custom icon, or NULL being returned because an
 *      error was encountered while attempting to generate the custom icon;
 *
 *      Pointer to an initialised IconParameters instance describing the way
 *      in which to generate the icons (only the SlipCover case definition part
 *      of this is consulted).
 *
 * Out: CGImageRef pointing to thumbnail image or NULL if there is an error, or
 *      if there is no need to assign a custom icon (no images in folder). If
 *      non-NULL, caller must CFRelease() the memory when finished.
\******************************************************************************/

static CGImageRef allocSlipCoverIcon( NSMutableArray * chosenImages,
                                      OSStatus       * thumbState,
                                      IconParameters * params )
{
    CGImageRef   finalImage  = NULL;
    NSImage    * sourceImage = nil;
    NSImage    * caseImage   = nil;

    @try
    {
        sourceImage = [ [ NSImage alloc ] initByReferencingFile: chosenImages[ 0 ] ];
        caseImage   = [ CaseGenerator caseImageAtSize: case512
                                                cover: sourceImage
                                       caseDefinition: params.slipCoverCase ];
    }
    @catch ( NSException * exception )
    {
        ( void ) exception; /* Ignore exception; caseImage is 'nil' */
    }

    if ( ! caseImage ) return nil; // Note early exit!

    /* The custom generator has historically always used CoreGraphics calls
     * directly and deals with CGImageRef values rather than NSImage pointers.
     * The SlipCover code doens't, so we have to convert to a CGImage using a
     * simplified piece of code that makes assumptions about the limited kind
     * of data that will be contained in an NSImage from SlipCover's generator
     * code (i.e. bitmaps only).
     */

    NSData * data = [ caseImage TIFFRepresentation ];

    if ( data != nil )
    {
        CGImageSourceRef imageSourceRef = CGImageSourceCreateWithData( ( __bridge CFDataRef ) data, NULL );
        finalImage = CGImageSourceCreateImageAtIndex( imageSourceRef, 0, NULL );
        CFRelease( imageSourceRef );
    }

imageGenerationFailed:

    ;
    return finalImage;
}

/******************************************************************************\
 * allocIconForFolder()
 *
 * Generate an icon for the folder identified by the given fully specified
 * POSIX-style pathname at CANVAS_SIZE x CANVAS_SIZE resolution (see the
 * "IconGenerator.h" header file). The caller is responsible for releasing the
 * returned object when it is no longer needed.
 *
 * The caller must ensure that an autorelease pool is available.
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
                               IconParameters * params )
{
    CGImageRef generatedImage = NULL;
    *thumbState = memFullErr; /* A potential valid failure mode */

    /* Find images */

    NSMutableArray * chosenImages = allocFoundImagePathArray
    (
      fullPosixPath,
      skipPackageLikeEntries,
      thumbState,
      params
    );

    /* Bail out if there are none */

    require( chosenImages != nil, nothingToDo );

    /* There are now two choices. Either we generate the image using SlipCover,
     * or the custom painting routines.
     */

    if ( params.slipCoverCase == nil )
    {
        generatedImage = allocCustomIcon
        (
            chosenImages,
            backgroundImage,
            opaque,
            thumbState,
            params
        );
    }
    else
    {
        generatedImage = allocSlipCoverIcon
        (
            chosenImages,
            thumbState,
            params
        );
    }

    /* Clear the precautionary pre-flagged error if everything looks OK */
    
    if ( generatedImage != NULL ) *thumbState = noErr;

nothingToDo:

    return generatedImage;
}
