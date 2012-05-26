/******************************************************************************\
 * Utilities: Miscellaneous.h
 *
 * Miscellaneous useful functions.
 *
 * (C) Hipposoft 2009-2012 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

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

CFStringRef getUti( FSRef * fsRef );

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

Boolean isLikeAPackage( NSString * fullPosixPath );

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

Boolean isImageFile( NSString * fullPosixPath );

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

OSErr sendFinderAppleEvent( AliasHandle aliasH, AEEventID appleEventID );

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

NSInteger dpiValue( NSInteger uncorrectedValue );
