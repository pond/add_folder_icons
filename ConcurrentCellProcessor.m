//
//  ConcurrentCellProcessor.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 5/03/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//
//  Class derived from NSOperation which can be used to concurrently process a
//  full POSIX path to a folder in order to update a preview image in a cell of
//  the main window's folder list taable.
//

#import "ConcurrentCellProcessor.h"

#import "GlobalConstants.h"
#import "CustomIconGenerator.h"

@interface ConcurrentCellProcessor()

/* All must *not* be 'nonatomic' */

@property NSTableView         * tableView;
@property NSArray             * tableContents;
@property NSMutableDictionary * rowDictionary;

- ( BOOL ) rowIsVisible;

@end

@implementation ConcurrentCellProcessor

/******************************************************************************\
 * -initForTableView:andRowDictionary:fromRow:
 *
 * Initialise the NSOperation derivative class. Local copies are taken of all
 * objects given in the input parameters so the caller can discard its own
 * copy immediately after calling if it so wishes.
 *
 * In:  ( NSTableView * ) tableView
 *      The main window's folder list's underlying table view.
 *
 *      ( NSArray * ) tableContents
 *      The live, caller-owned array of table contents underneath the given
 *      table view.
 *
 *      ( NSMutableDictionary * ) rowDictionary
 *      A *mutable* dictionary THAT WILL BE CHANGED which comes out of the
 *      given 'tableContents' array entries - the actual data source for
 *      the table view in the first parameter. At the time you're calling
 *      this init method, the contents don't matter; but by the time this
 *      operation is added to a queue, it MUST contain the following data:
 *
 *        @"path"    - Full POSIX path of the folder in this row of data
 *        @"style"   - The IconStyle instance for the style for that folder
 *        @"preview" - The preview data; an NSDictionary
 *
 *      It is the @"preview" key's dictionary that will be changed if the cell
 *      processing operation runs successfully. By the time this instantiated
 *      operation is added to a queue, the preview dictionary MUST contain
 *      the following data:
 *
 *        @"styleID"       - the IconStyle instance's "objectID"
 *        @"cellProcessor" - this cell processing instance; i.e. the return
 *                           value of this initialisation method.
 *
 *      When the operation is running, it frequently checks to see if the
 *      @"styleID" value is still correct or if cancellation has happened and
 *      bails if anything looks odd - it means the table data is being changed
 *      and the operation no longer considers itself relevant. Likewise, when
 *      everything is done and a main thread table update is being scheduled,
 *      the dictionary is checked one last time *on the main thread* to make
 *      sure that both style ID and cell processor reference match up. Only if
 *      all these things happen will the operation finish successfully. When it
 *      does so, it *replaces* the @"preview" dictionary with a new one which
 *      holds the following data:
 *
 *        @"styleID"      - the IconStyle instance's "objectID"
 *        @"previewImage" - the generated NSImage to use on this row
 *
 *      The table view given in the first parameter is then told to reload the
 *      table data to enforce a general redraw.
 *
 *      Note that if the operation self-terminates early for any reason, it
 *      will clear out the data in @"preview" so that the main thread does not
 *      accidentally assume a processor is still running when in fact it isn't.
 *
 * Out: self.
\******************************************************************************/

- ( instancetype ) initForTableView: ( NSTableView         * ) tableView
                   andTableContents: ( NSArray             * ) tableContents
                   andRowDictionary: ( NSMutableDictionary * ) rowDictionary
{
    if ( ( self = [ super init ] ) )
    {
        _tableView     = tableView;
        _tableContents = tableContents;
        _rowDictionary = rowDictionary;
    }

    return self;
}

/******************************************************************************\
 * -rowIsVisible
 *
 * Private method. Is the table row the operation was created for visible?
 *
 * Out: YES if the row is (still) fully or partially visible, else NO.
\******************************************************************************/

- ( BOOL ) rowIsVisible
{
    NSScrollView * scrollView  = [ self.tableView enclosingScrollView ];
    CGRect         visibleRect = scrollView.contentView.visibleRect;
    NSRange        range       = [ self.tableView rowsInRect: visibleRect ];
    NSInteger      foundIndex  =
    [
        self.tableContents indexOfObjectWithOptions: NSEnumerationConcurrent
                                        passingTest:

        ^ BOOL ( NSDictionary * dict, NSUInteger index, BOOL * stop )
        {
            if ( dict == self.rowDictionary )
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

    return NSLocationInRange( foundIndex, range );
}

/******************************************************************************\
 * -main
 *
 * The implementation of this operation. For its behaviour, see the description
 * of -initForTableView:andRowDictionary:fromRow:.
\******************************************************************************/

- ( void ) main
{
    @autoreleasepool
    {
        @try
        {
            NSString  * fullPOSIXPath = self.rowDictionary[ @"path"  ];
            IconStyle * iconStyle     = self.rowDictionary[ @"style" ];

            CustomIconGenerator * generator =
            [
                [ CustomIconGenerator alloc ] initWithIconStyle: iconStyle
                                                   forPOSIXPath: fullPOSIXPath
            ];

            /* Avoid unnecessary work generating the icon if cancelled or no
             * longer visible.
             */

            if ( self.isCancelled ) return;

            if ( [ self rowIsVisible ] == NO )
            {
                self.rowDictionary[ @"preview" ] = nil;
                return;
            }

            CGImageRef finalImage = [ generator generate: nil ];

            if ( finalImage )
            {
                NSImage * image;
                NSSize    imageSize = NSSizeFromString( @"{64,64}" );

                /* One last chance to avoid unnecessary work creating the
                 * NSImage. After that, might as well carry on.
                 */

                if ( self.isCancelled || [ self rowIsVisible ] == NO )
                {
                    self.rowDictionary[ @"preview" ] = nil;
                    return;
                }

                image = [ [ NSImage alloc ] initWithCGImage: finalImage size: imageSize ];
                CFRelease( finalImage );

                dispatch_async
                (
                    dispatch_get_main_queue(),
                    ^{
                        /* By the time we get to running here over in the main
                         * thread, are we still relevant? The row dictionary
                         * preview data for this cell processor should match
                         * our expectations.
                         */

                        id currentStyleID   = self.rowDictionary[ @"preview" ][ @"styleID"       ];
                        id currentProcessor = self.rowDictionary[ @"preview" ][ @"cellProcessor" ];

                        if ( currentProcessor == self && currentStyleID == iconStyle.objectID )
                        {
                            self.rowDictionary[ @"preview" ] =
                            @{
                                @"styleID":      iconStyle.objectID,
                                @"previewImage": image
                            };

                            [ self.tableView reloadData ];
                        }
                    }
                );
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
        }
    }
}

@end
