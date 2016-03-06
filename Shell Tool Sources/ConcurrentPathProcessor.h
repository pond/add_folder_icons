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
#import "CustomIconGenerator.h"

@interface ConcurrentPathProcessor : NSOperation
{
}

@property          CustomIconGenerator * iconGenerator;
@property ( copy ) NSString            * pathData;

- ( instancetype ) init NS_UNAVAILABLE; /* Use -initWithIconStyle:... instead */
- ( instancetype ) initWithIconStyle: ( IconStyle * ) theIconStyle
                        forPOSIXPath: ( NSString  * ) thePosixPath;

@end /* @interface ConcurrentPathProcessor : NSOperation */
