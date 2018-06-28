/******************************************************************************\
 * Utilities: Icons.m
 *
 * Useful icon handling functions. Requires "Utilities: Miscellaneous" library.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import "Icons.h"
#import "GlobalConstants.h" /* For CANVAS_SIZE only */

/* Local functions */

static OSStatus addImages      ( IconFamilyHandle iconHnd,
                                 CGImageRef       cgImage );

static OSStatus addImage       ( IconFamilyHandle iconHnd,
                                 CGImageRef       cgImage,
                                 CGColorSpaceRef  cgColourSpace,
                                 size_t           width );

static OSStatus addImageOrMask ( IconFamilyHandle iconHnd,
                                 CGImageRef       cgImage,
                                 CGColorSpaceRef  cgColourSpace,
                                 size_t           width,
                                 Boolean          mask );

///******************************************************************************\
// * allocFolderIcon()
// *
// * Obtain an CGImageRef containing the standard folder icon. Returns the
// * largest icon available. Caches the result in a local static variable; call
// * from the main thread only the first time around, or anywhere subsequently.
// *
// * In:  N/A
// *
// * Out: CGImageRef for the standard folder icon image, or NULL if something
// *      went wrong.
//\******************************************************************************/
//
//CGImageRef allocFolderIcon( void )
//{
//    static CGImageRef folderIconRef = NULL;
//
//    if ( folderIconRef == NULL )
//    {
//        NSImage * folder = [ NSImage imageNamed: NSImageNameFolder ];
//
//        if ( folder )
//        {
//            /* To turn into a CGImage, just try to fill the canvas with the folder
//             * icon. The OS selects the best image.
//             *
//             * We *DO NOT* adjust the requested size for retina DPI. The OS does
//             * that internally, it seems; at least on OS X 10.11, requesting an
//             * adjusted 512 for high DPI and thus asking for 1024, results in a
//             * failure to fetch an image and a logged complaint from
//             * iconservicesagent about being able to find a 2048x2048 image.
//             */
//
//            NSInteger  canvasSize = CANVAS_SIZE; /* (was 'dpiValue( CANVAS_SIZE )' */
//            NSRect     imageRect  = NSMakeRect( 0, 0, canvasSize, canvasSize );
//            CGImageRef localRef   =
//            [
//                folder CGImageForProposedRect: &imageRect
//                                      context: nil
//                                        hints: nil
//            ];
//
//            /* The above is owned by the NSImage and when the NSImage goes, the
//             * folder goes with it. We need to store a copy.
//             */
//
//            if ( localRef )
//            {
//                folderIconRef = CGImageCreateCopy( localRef );
//            }
//        }
//    }
//
//    return folderIconRef;
//}

/******************************************************************************\
 * createIconFamilyFromCGImage()
 *
 * Given a CGImage, returns an IconFamilyHandle for an icon family containing
 * a 'huge' 512x512 RGBA icon type and several smaller sizes generated by
 * scaling down the input image. Without these smaller sizes, the Finder will
 * run very slowly if displaying a file or folder to which the icon family has
 * been assigned as a custom icon set. Ideally the input CGImage should be
 * that size, but if not, it will be stretched to fit.
 *
 * Heavily based upon:
 *
 *   http://www.carbondev.com/site/?page=GetIconRefFromCGImage
 *
 * In:  CGImageRef for the image of interest.
 * Out: IconFamilyHandle for the equivalent 512x512 RGBA icon, or NULL if
 *      anything went wrong. Note that the caller is responsible for calling
 *      DisposeHandle() on a non-NULL return value when the icon family is no
 *      longer needed.
\******************************************************************************/

OSStatus createIconFamilyFromCGImage( CGImageRef cgImage, IconFamilyHandle * iconHndRef )
{
    SInt32           theSize;
    IconFamilyHandle iconHnd = NULL;
    OSStatus         err     = memFullErr;

    *iconHndRef = NULL;

    /* Create an icon family handle. An icon family handle is just a fixed
     * (big-endian) header and tagged data.
     */

    theSize = sizeof( OSType ) * 2;
    iconHnd = ( IconFamilyHandle ) NewHandle( theSize );

    __Require( iconHnd, bailOut );

    ( *iconHnd )->resourceType = EndianU32_NtoB( kIconFamilyType );
    ( *iconHnd )->resourceSize = EndianU32_NtoB( theSize         );

    /* Add the images and return the handle of the populated icon family */

    err = addImages( iconHnd, cgImage );
    __Require( err == noErr, bailOut );

    *iconHndRef = iconHnd;
    return noErr;

bailOut:

    if ( iconHnd != NULL ) DisposeHandle( ( Handle ) iconHnd );
    return err;
}

/******************************************************************************\
 * hasCustomIcon()
 *
 * Does the given file or folder appear to have a custom icon defined? Code is
 * based on the implementation for "saveCustomIcon" so see that for further
 * background information.
 *
 * In:  Full POSIX path of file or folder to update;
 *
 * Out: YES if there's a custom icon resource, NO for any other condition
 *      (including internal errors).
\******************************************************************************/

Boolean hasCustomIcon( NSString * fullPosixPath )
{
    Boolean       result = NO;
    OSStatus      err;
    Boolean       dir;
    FSRef         ref;
    HFSUniStr255  fork = { 0, };
    ResFileRefNum refNum = kResFileNotOpened;

    /* Get an FSRef to refer to the file of interest */

    err = FSPathMakeRef
    (
        ( UInt8 * ) [ fullPosixPath fileSystemRepresentation ], &ref, &dir
    );

    __Require( err == noErr, bailOut );

    /* If it's a directory, change to looking for the resource file inside */

    if ( dir )
    {
        Boolean    ignored;
        NSString * iconPath =
        [
            fullPosixPath stringByAppendingPathComponent: @"Icon\r"
        ];

        err = FSPathMakeRef
        (
            ( const UInt8 * ) [ iconPath UTF8String ],
            &ref,
            &ignored
        );

        __Require( err == noErr, bailOut );
    }

    /* Open the resource fork; if this fails, assume no resource fork and
     * bail out with the default result of no custom icon.
     */

    FSGetResourceForkName( &fork );

    err = FSOpenResourceFile
    (
        &ref,
        fork.length,
        fork.unicode,
        fsRdPerm,
        &refNum
    );

    __Require( err == noErr, bailOut );

    /* Provided that the resources file was opened, check for the 'icns'
     * resource explicitly and if found, note that there was a custom icon
     * present. Tidy up and close the resources file.
     */

    if ( refNum != kResFileNotOpened )
    {
        UseResFile( refNum );

        Handle h = Get1Resource( 'icns', kCustomIconResource );
        if ( h != NULL ) result = YES;

        CloseResFile( refNum ); /* This disposes of handle 'h' in passing */
    }

bailOut:

    return result;
}

/******************************************************************************\
 * saveCustomIcon()
 *
 * Saves a custom icon for the given file. Note that custom disk (volume) icons
 * are not supported, but custom icons for regular files and folders should
 * work fine.
 *
 * The code does not work reliably when called from parallel threads, so
 * for such use cases, consider using the global locking semaphore. See
 * "globalSemaphoreInit" in "GlobalSemaphore.[h|m]".
 *
 * The function is a hybrid based on adaptation and a combination of code at:
 *
 *   http://developer.apple.com/samplecode/SetCustomIcon/
 *   http://www.cocoabuilder.com/archive/message/cocoa/2004/2/3/95889
 *
 * In:  Full POSIX path of file or folder to update;
 *
 *      IconFamilyHandle for the icon to set (see "createIconFamilyFromCGImage"
 *      for one of many different ways to obtain such a thing).
 *
 * Out: Error indication - noErr if OK, else failed.
\******************************************************************************/

OSStatus saveCustomIcon( NSString * fullPosixPath, IconFamilyHandle icnsH )
{
    OSStatus      err;
    FSCatalogInfo info;
    FSRef         par;
    FSRef         ref;
    Boolean       dir = false;

    err = FSPathMakeRef
    (
        ( UInt8 * ) [ fullPosixPath fileSystemRepresentation ], &par, &dir
    );

    __Require( err == noErr, bailOut );

    HFSUniStr255  fork   = { 0, };
    ResFileRefNum refNum = kResFileNotOpened;

    /* Create a resource fork to hold the icon; folders do this using a file
     * called "ICON\r".
     */

    FSGetResourceForkName( &fork );

    if ( dir )
    {
        UniChar iconName[ 5 ] = { 'I', 'c', 'o', 'n', '\r' };

        /* Make the file invisible. The next bit comes from Icon Family -
         * it reckons the type and creator should be set.
         */

        bzero( &info, sizeof( info ) );

        struct FileInfo * finderInfo = ( ( FileInfo * ) ( &info.finderInfo ) );

        finderInfo->finderFlags = kIsInvisible;
        finderInfo->fileType    = 'icon';
        finderInfo->fileCreator = 'MACS';

        err = FSCreateResourceFile
        (
            &par,
            5,
            iconName,
            kFSCatInfoFinderInfo,
            &info,
            fork.length,
            fork.unicode,
            &ref,
            NULL
        );

        if ( err == dupFNErr )
        {
            /* Resource already exists - trouble is, 'ref' has not been
             * filled in yet; must do that now.
             */

            Boolean    ignored;
            NSString * iconPath =
            [
                fullPosixPath stringByAppendingPathComponent: @"Icon\r"
            ];

            err = FSPathMakeRef
            (
                ( const UInt8 * ) [ iconPath UTF8String ],
                &ref,
                &ignored
            );
        }
    }
    else
    {
        memmove( &par, &ref, sizeof( FSRef ) );

        err = FSCreateResourceFork
        (
            &ref,
            fork.length,
            fork.unicode,
            0
        );
    }

    /* "dupFNErr" is allowed - means resource fork already exists */

    __Require( err == noErr || err == dupFNErr, bailOut );

    /* Open the resource file ready for writing */

    err = FSOpenResourceFile
    (
        &ref,
        fork.length,
        fork.unicode,
        fsRdWrPerm,
        &refNum
    );

    __Require( err == noErr, bailOut );

    if ( refNum == kResFileNotOpened )
    {
        err = readErr;
        goto bailOut;
    }

    /* Then, with this resource file... */

    UseResFile( refNum );

    /* If it already has a custom icon, remove it first */

    Handle h = Get1Resource( 'icns', kCustomIconResource );

    if ( h != NULL )
    {
        RemoveResource( h );
        DisposeHandle( h );
    }

    /* Create a new resource ("icns", -16455). Add the resource,
     * write the resource and detach it (we can't alter it but we
     * can still refer to it later).
     */

    AddResource( ( Handle ) icnsH, 'icns', kCustomIconResource, "\p" );
    err = ResError();
    __Require( err == noErr, bailOut );

    WriteResource( ( Handle ) icnsH );
    err = ResError();
    __Require( err == noErr, bailOut );

    DetachResource( ( Handle ) icnsH );
    err = ResError();
    __Require( err == noErr, bailOut );

    /* All done - close the resource fork */

    CloseResFile( refNum );

    /* Set the 'has custom icon' attribute */

    err = FSGetCatalogInfo
    (
        &par,
        kFSCatInfoFinderInfo,
        &info,
        NULL,
        NULL,
        NULL
    );

    __Require( err == noErr, bailOut );

    ( ( FileInfo * ) ( &info.finderInfo ) )->finderFlags = kHasCustomIcon;

    err = FSSetCatalogInfo( &par, kFSCatInfoFinderInfo, &info );
    __Require( err == noErr, bailOut );

    /* Tell the finder about the change */

    err = FNNotify( &par, kFNDirectoryModifiedMessage, kNilOptions );

bailOut:

    return err;
}

/******************************************************************************\
 * addImages()
 *
 * Internal - to the icon family identified by the given handle, add the
 * given image in various different sizes.
 *
 * In:  Icon family handle;
 *
 *      Reference to a Core Graphics image which should be 512x512 pixels in
 *      size (other image sizes will work, but will be inefficient).
 *
 * Out: OSStatus indication of error ('noErr' if all goes well).
\******************************************************************************/

static OSStatus addImages( IconFamilyHandle iconHnd,
                           CGImageRef       cgImage )
{
    CGColorSpaceRef cgColourSpace = CGColorSpaceCreateDeviceRGB();
    if ( cgColourSpace == NULL ) return memFullErr;

    /* The full set of icons consists of:
     *
     *   512x512 and 256x256 RGBA icons; 128x128, 32x32 and 16x16 icons
     *   with 8-bit alpha and RGB data in separate channels; and 32x32 and
     *   16x16 icons with 1-bit alpha and 8-bit colour.
     *
     * The Snow Leopard Finder seems happy with just 512x512 but does seem to
     * suffer from an occasional bug, if a very large number of icons are
     * updated at once, where it stops display high resolution content. Unless
     * a 32x32 size is present it will display blank icons and may crash. With
     * 32x32 resolution icons included, at least a blocky icon is shown and
     * the Finder tends not to fall over. If the Finder is restarted the icons
     * show up fine, so this does seem to be a display issue rather than a
     * generator code issue.
     *
     * Earlier versions of Add Folder Icons only generated the minimum set of
     * 512x512 and 32x32 icons, to improve generation time. This turns out to
     * give a noticeable performance penalty during display in the Finder and
     * the display-time performance is more important than the generator
     * performace, as display happens much more often. Adding in 128x128 is a
     * reasonable compromise, as Finder icons are rarely displayed larger than
     * this under general use and scaling down a 128x128 icon at run-time is
     * a fair bit quicker than scaling down a 512x512 icon.
     *
     * If the DPI value translation routine seems to be returning updated
     * values, add in the additional icon size of 1024x1024 for high DPI modes
     * modes (for 'correctness', the translated value of 512x512 is used, just
     * in case the translation factor ever differs from multiply-by-two).
     *
     * OS X 10.13 introduced a bug in the OS image generation code and/or the
     * Finder. Retina icons generated in earlier OS versions display correctly
     * in the Finder in high DPI display modes, but retina icons generated in
     * OS X 10.13 itself don't display correctly in the OS X 10.13 Finder.
     * Things work fine in standard DPI display modes, just not in high DPI.
     *
     *   https://bugreport.apple.com/web/?problemID=35990277
     *
     * This remained broken for the entire 10.13 lifecycle but was happily
     * fixed during the 10.14 beta, so we skip the high end icon for OS X
     * 10.13 only.
     *
     * Comment or uncomment lines below to include or exclude sizes. All
     * relevant colour and mask variations are handled automatically for any
     * given size out of dpiValue(512), 512, 256, 128, 32 or 16.
     */

    OSStatus                 err     = noErr;
    NSOperatingSystemVersion version = [ [ NSProcessInfo processInfo ] operatingSystemVersion ];

    if ( dpiValue( 1 ) != 1 && version.minorVersion != 13 )
    {
        err = addImage( iconHnd, cgImage, cgColourSpace, dpiValue( 512 ) );
    }

    if ( err == noErr ) err = addImage( iconHnd, cgImage, cgColourSpace, 512 );

#ifdef GENERATE_ALL_ICON_SIZES
    if ( err == noErr ) err = addImage( iconHnd, cgImage, cgColourSpace, 256 );
    if ( err == noErr ) err = addImage( iconHnd, cgImage, cgColourSpace, 128 );
    if ( err == noErr ) err = addImage( iconHnd, cgImage, cgColourSpace,  32 );
    if ( err == noErr ) err = addImage( iconHnd, cgImage, cgColourSpace,  16 );
#endif

    CFRelease( cgColourSpace );
    return err;
}

/******************************************************************************\
 * addImage()
 *
 * Internal - to the icon family identified by the given handle, add the
 * given image by painting using the given colour space at the given width.
 * The icon height is set to the same value. Widths of 512, 256, 128, 32 and
 * 16 are supported. Other widths will provoke undefined behaviour.
 *
 * In:  Icon family handle;
 *
 *      Reference to a Core Graphics image which should be 512x512 pixels in
 *      size (other image sizes will work, but will be inefficient);
 *
 *      Reference to a colour space in which to work (usually created via a
 *      call to 'CGColorSpaceCreateDeviceRGB');
 *
 *      Width of icon to add in pixels. Height is set to match. Must be one
 *      value out of 512, 256, 128, 32 or 16.
 *
 * Out: OSStatus indication of error ('noErr' if all goes well).
\******************************************************************************/

static OSStatus addImage( IconFamilyHandle iconHnd,
                          CGImageRef       cgImage,
                          CGColorSpaceRef  cgColourSpace,
                          size_t           width )
{
    OSStatus err = addImageOrMask( iconHnd, cgImage, cgColourSpace, width, NO );

    /* Note that this is a bit inefficient for images that need separate masks
     * since the source Core Graphics image will be scaled to the same size
     * twice, once while painting the image and once while painting its mask.
     */

    if ( err == noErr && width < 256 )
    {
        addImageOrMask( iconHnd, cgImage, cgColourSpace, width, YES );
    }

    return err;
}

/******************************************************************************\
 * addImageOrMask()
 *
 * Internal - as "addImage", but the caller has control of whether an image or
 * image mask gets added to the icon family for widths of 128, 32 or 16. Widths
 * of 256 or 512 use a merged RGBA mask and image data format so both are
 * always added at the same time.
 *
 * The requested width will be limited so that it does not exceed CANVAS_SIZE.
 *
 * In:  Icon family handle;
 *
 *      Reference to a Core Graphics image which should be 512x512 pixels in
 *      size (other image sizes will work, but will be inefficient);
 *
 *      Reference to a colour space in which to work (usually created via a
 *      call to 'CGColorSpaceCreateDeviceRGB');
 *
 *      Width of icon to add in pixels. Height is set to match. Must be one
 *      value out of 512, 256, 128, 32 or 16, else behaviour is undefined;
 *
 *      YES to add the image mask (only for widths 128, 32 or 16), else NO.
 *      Using YES for other image widths will provoke undefined behaviour.
 *
 * Out: OSStatus indication of error ('noErr' if all goes well).
\******************************************************************************/

static OSStatus addImageOrMask( IconFamilyHandle iconHnd,
                                CGImageRef       cgImage,
                                CGColorSpaceRef  cgColourSpace,
                                size_t           width,
                                Boolean          mask )
{
    size_t           pixelSize, dataSize;
    CGImageAlphaInfo info;
    OSType           type;

    /* Figure out the various types and sizes needed */

    if ( mask == YES )
    {
        /* Width of 128, 32 or 16, else undefined results */

        pixelSize = 1;
        info      = kCGImageAlphaOnly;

        switch( width )
        {
            default: type = kThumbnail8BitMask; break; /* 128 or unknown */
            case 32: type = kLarge8BitMask;     break;
            case 16: type = kSmall8BitMask;     break;
        }
    }
    else
    {
        /* Width of 512, 256, 128, 32 or 16, else undefined results */

        pixelSize = 4;

        if ( width >= 256 ) info = kCGImageAlphaPremultipliedFirst;
        else                info = kCGImageAlphaNoneSkipFirst;

        switch( width )
        {
            default:   type = kIconServices512PixelDataARGB;  break; /* 512 or unknown     */
            case 1024: type = kIconServices1024PixelDataARGB; break; /* OS X 10.7 or later */
            case 256:  type = kIconServices256PixelDataARGB;  break;
            case 128:  type = kThumbnail32BitData;            break;
            case 32:   type = kLarge32BitData;                break;
            case 16:   type = kSmall32BitData;                break;
        }
    }

    NSInteger canvasSize = dpiValue( CANVAS_SIZE );
    if ( width > canvasSize ) width = canvasSize;

    dataSize = width * width * pixelSize;

    /* Clear the paint buffer and create a context within it */

    UInt32 * paintBuffer = calloc( dataSize, sizeof( UInt32 ) );
    if ( ! paintBuffer ) return memFullErr;

    CGContextRef cgContext = CGBitmapContextCreate
    (
        paintBuffer,
        width,
        width,
        8,
        width * pixelSize,
        ( mask == YES ) ? NULL : cgColourSpace,
        info
    );

    if ( cgContext == NULL )
    {
        free( paintBuffer );
        return memFullErr;
    }

    /* Paint the image */

    CGContextDrawImage( cgContext, CGRectMake( 0, 0, width, width ), cgImage );
    CFRelease( cgContext );

    /* Add it to the icon collection */

    Handle   tmpHnd;
    OSStatus err;

    err = PtrToHand( paintBuffer, &tmpHnd, dataSize );

    free( paintBuffer );
    if ( err != noErr ) return err;

    err = SetIconFamilyData( iconHnd, type, tmpHnd );
    DisposeHandle( tmpHnd );
    return err;
}
