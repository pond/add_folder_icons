/******************************************************************************\
 * addfoldericons: ConcurrentPathProcessor.h
 *
 * Derive a class from NSOperation which can be used to concurrently process a
 * full POSIX path to a folder in order to update that folder's icon. The class
 * may be run by, for example, adding it as an operation to an NSOperationQueue
 * instance.
 *
 * (C) Hipposoft 2009, 2010, 2011 <ahodgkin@rowing.org.uk>
\******************************************************************************/

#import <Cocoa/Cocoa.h>
#import "IconParameters.h"

@interface ConcurrentPathProcessor : NSOperation
{
}

-( id ) init NS_UNAVAILABLE; /* Use -initWithPath:... instead */

@property ( strong, nonatomic ) NSString       * pathData;
@property                       CGImageRef       backgroundRef;
@property ( strong, nonatomic ) IconParameters * iconParameters;

/* Initialise the class by passing a full POSIX path to the folder of interest
 * and a background image or NULL. For more on this second parameter, see the
 * documentation in the library code for the "backgroundImage" parameter of
 * "allocIconForFolder" in "IconGenerator.[h|m]". Pass also a pointer to an
 * initialised icon parameters structure describing how the icons are to be
 * constructed. A deep copy of this is taken internally so the caller can
 * discard their copy afterwards.
 */

-( instancetype ) initWithPath: ( NSString       * ) fullPosixPath
                 andBackground: ( CGImageRef       ) backgroundImage
                 andParameters: ( IconParameters * ) params NS_DESIGNATED_INITIALIZER;

@end /* @interface ConcurrentPathProcessor : NSOperation */
