//
//  VerticallyAlignedTextFieldCell.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 27/02/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//
//  Vertically centred text for NSTextFieldCell-based table cells in
//  cell-based NSTableViews. See:
//
//    http://stackoverflow.com/questions/2103125/vertically-aligning-text-in-nstableview-row
//

#import "VerticallyAlignedTextFieldCell.h"

@implementation VerticallyAlignedTextFieldCell

- ( NSRect ) titleRectForBounds: ( NSRect ) theRect
{
    NSRect titleFrame = [ super titleRectForBounds: theRect ];
    NSSize titleSize  = [ [ self attributedStringValue ] size ];

    titleFrame.origin.y = theRect.origin.y - .5 + ( theRect.size.height - titleSize.height ) / 2.0;

    return titleFrame;
}

- ( void ) drawInteriorWithFrame: ( NSRect ) cellFrame inView: ( NSView * ) controlView
{
    NSRect titleRect = [ self titleRectForBounds: cellFrame ];
    [ [ self attributedStringValue ] drawInRect: titleRect ];
}

@end
