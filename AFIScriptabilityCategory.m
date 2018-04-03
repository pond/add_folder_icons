//
//  AFIScriptabilityCategory.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 28/03/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//
//  Based on:
//  https://www.apeth.net/matt/scriptability/scriptabilityTutorial.html
//

#import "AFIScriptabilityCategory.h"

#import "IconStyle.h"
#import "IconStyleManager.h"

#pragma mark - NSObject extensions

@implementation NSObject ( AFIScriptabilityCategory )

- ( void ) returnError: ( int ) errorNumber string: ( NSString * ) message
{
    NSScriptCommand * command = [ NSScriptCommand currentCommand ];

    [ command setScriptErrorNumber: errorNumber ];
    if ( message ) [ command setScriptErrorString: message ];
}

@end

#pragma mark - MainMenuController extensions

@implementation NSApplication ( AFIScriptabilityCategory )

// This is deprecated on OS X 10.10 or later and the documentation says "do
// not implement this method" (!) but we've no choice, because we run on OS
// X 10.6 and later - it's required for 10.6-10.9.
//
// Given its uncertain status, always return YES!
//
- ( BOOL ) application: ( NSApplication * ) sender
    delegateHandlesKey: ( NSString      * ) key
{
    return YES;
}

- ( NSArray * ) iconStyleArray
{
    IconStyleManager * iconStyleManager = [ IconStyleManager iconStyleManager ];

    return [ iconStyleManager getStyles ];
}

- ( unsigned long ) countOfIconStyleArray
{
    IconStyleManager * iconStyleManager = [ IconStyleManager iconStyleManager ];

    return [ [ iconStyleManager getStyles ] count ];
}

- ( IconStyle * ) objectInIconStyleArrayAtIndex: ( unsigned int ) index
{
    IconStyleManager * iconStyleManager = [ IconStyleManager iconStyleManager ];

    return [ iconStyleManager getStyles ][ index ];
}

- ( IconStyle * ) valueInIconStyleArrayAtIndex: ( unsigned int ) index
{
    IconStyleManager * iconStyleManager = [ IconStyleManager iconStyleManager ];
    NSArray          * iconStyles       = [ iconStyleManager getStyles ];

    if ( ! [ [ NSScriptCommand currentCommand ] isKindOfClass: [ NSExistsCommand class ] ] )
    {
        if ( index >= iconStyles.count )
        {
            [ self returnError: errAENoSuchObject string: @"No such icon style." ];
            return nil;
        }
    }

    return iconStyles[ index ];
}

- ( IconStyle * ) valueInIconStyleArrayWithName: ( NSString * ) name
{
    IconStyleManager * iconStyleManager = [ IconStyleManager iconStyleManager ];
    IconStyle        * iconStyle        = [ iconStyleManager findStyleByName: name ];

    if ( ! [ [ NSScriptCommand currentCommand ] isKindOfClass: [ NSExistsCommand class ] ] )
    {
        if ( iconStyle == nil )
        {
            [ self returnError: errAENoSuchObject string: @"No such icon style." ];
            return nil;
        }
    }

    return iconStyle;
}

@end

@implementation IconStyle ( AFIScriptabilityCategory )

- ( NSScriptObjectSpecifier * ) objectSpecifier
{
    NSLog(@"personObjectSpecifier");

    NSScriptClassDescription * appDesc = ( NSScriptClassDescription * ) [ NSApp classDescription ];

    return
    [
        [ NSNameSpecifier alloc]
        initWithContainerClassDescription: appDesc
                       containerSpecifier: nil
                                      key: @"iconStyleArray"
                                     name: [ self name ]
    ];
}

@end
