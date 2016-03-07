//
//  AFIApplyCommand.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 6/03/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//

#import "CoreServices/CoreServices.h" /* ...just for MacErrors.h, really */

#import "AFIApplyCommand.h"

#import "GlobalConstants.h"
#import "IconStyleManager.h"
#import "ConcurrentPathProcessor.h"

@implementation AFIApplyCommand

- ( id ) performDefaultImplementation
{
    NSDictionary * args          = [ self evaluatedArguments ];
    NSString     * iconStyleName = @"";
    NSArray      * listOfFiles   = @[];

    /* Since the scripting definition file says that the two parameters are not
     * optional, any AppleScript execution environment out to reject attempts
     * to call us without two arguments exactly. But just in case...
     */

    if ( args.count != 2 )
    {
        NSString * errorMessage = NSLocalizedString( @"An icon style name parameter and 'to <folder list>' parameter are required for the verb 'apply'.",  @"Error message shown by the AppleScript 'apply' command handler if an incorrect number of parameters is supplied" );

        [ self setScriptErrorNumber: errOSAScriptError ];
        [ self setScriptErrorString: errorMessage      ];

        return nil;
    }

    iconStyleName = [ args valueForKey: @"" ]; /* (The direct argument) */
    listOfFiles   = [ args valueForKey: @"toFolders" ];

    /* Now for the real work */

    IconStyle * iconStyle = [ [ IconStyleManager iconStyleManager ] findStyleByName: iconStyleName ];

    if ( iconStyle == nil )
    {
        NSString * errorMessage =
        [
            NSString stringWithFormat: NSLocalizedString( @"Icon style name '%@' not found", @"Error message shown by the AppleScript 'apply' command handler if the requested icon style cannot be found"),
                                       iconStyleName
        ];

        [ self setScriptErrorNumber: errOSAScriptError ];
        [ self setScriptErrorString: errorMessage      ];

        return nil;
    }

    NSOperationQueue * queue = [ [ NSOperationQueue alloc ] init ];

    /* AppleScript sends 'file' types as NSURLs */

    for ( NSURL * fileURL in listOfFiles )
    {
        ConcurrentPathProcessor * processThisPath =
        [
            [ ConcurrentPathProcessor alloc ] initWithIconStyle: iconStyle
                                                   forPOSIXPath: [ fileURL path ]
        ];

        [ queue addOperation: processThisPath ];
    }

    [ queue waitUntilAllOperationsAreFinished ];

    if ( globalErrorFlag )
    {
        NSString * errorMessage = NSLocalizedString( @"One or more icon addition attempts failed.",  @"Error message shown by the AppleScript 'apply' command handler if not all addition operations succeed" );

        [ self setScriptErrorNumber: errOSAScriptError ];
        [ self setScriptErrorString: errorMessage      ];

        return nil;
    }

    return nil;
}

@end
