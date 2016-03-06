//
//  ConcurrentCellProcessor.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 5/03/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//
//  Class derived from NSOperation which can be used to concurrently process a
//  full POSIX path to a folder in order to update a preview image in a cell of
//  the main window's folder list taable.
//

#import <Foundation/Foundation.h>

@interface ConcurrentCellProcessor : NSOperation

- ( instancetype ) initForTableView: ( NSTableView         * ) tableView
                   andTableContents: ( NSArray             * ) tableContents
                   andRowDictionary: ( NSMutableDictionary * ) rowDictionary;

@end
