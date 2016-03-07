//
//  AFIRemoveCommand.m
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 7/03/16.
//  Copyright © 2016 Hipposoft. All rights reserved.
//

#import "CoreServices/CoreServices.h" /* ...just for MacErrors.h, really */

#import "AFIRemoveCommand.h"

#import "GlobalConstants.h"
#import "IconStyleManager.h"
#import "ConcurrentPathProcessor.h"

@implementation AFIRemoveCommand

- ( id ) performDefaultImplementation
{
    NSWorkspace  * workspace   = [ NSWorkspace sharedWorkspace ];
    NSDictionary * args        = [ self evaluatedArguments ];
    NSArray      * listOfFiles = @[];

    /* Since the scripting definition file says that the one parameter is not
     * optional, any AppleScript execution environment out to reject attempts
     * to call us without one arguments exactly. But just in case...
     */

    if ( args.count != 1 )
    {
        NSString * errorMessage = NSLocalizedString( @"A 'from <folder list>' parameter is required for the verb 'remove'.",  @"Error message shown by the AppleScript 'remove' command handler if an incorrect number of parameters is supplied" );

        [ self setScriptErrorNumber: errOSAScriptError ];
        [ self setScriptErrorString: errorMessage      ];

        return nil;
    }

    listOfFiles = [ args valueForKey: @"fromFolders" ];

    /* AppleScript sends 'file' types as NSURLs */

    for ( NSURL * fileURL in listOfFiles )
    {
        [ workspace setIcon: nil forFile: [ fileURL path ] options: 0 ];
    }

    return nil;
}

@end
