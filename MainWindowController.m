//
//  MainWindowController.m
//
//  Created by Andrew Hodgkinson on 28/03/2010.
//  Copyright 2010, 2011 Hipposoft. All rights reserved.
//

//#import "IconParameters.h"

#import "MainWindowController.h"
#import "ApplicationSupport.h"

#import "IconParameters.h"
#import "GlobalSemaphore.h"
#import "ConcurrentPathProcessor.h"

#include <CoreFoundation/CoreFoundation.h>

#define NSINDEXSET_ON_PBOARD @"NSIndexSetOnPboardType"

@implementation MainWindowController

@synthesize iconStyleManager,
            managedObjectContext,
            managedObjectModel;

- ( void ) awakeFromNib
{
    tableContents = [ [ NSMutableArray alloc ] init ];

    [ self initOpenPanel      ];
    [ self initWindowContents ];

    /* Set up a communications channel through which the command line tool
     * can talk to us.
     */

    [ NSThread detachNewThreadSelector: @selector( doCommsThread )
                              toTarget: self
                            withObject: nil ];
}


/******************************************************************************\
 * -initWithWindowNibName:
 *
 * Initialise the class, internally recording (and indeed creating, if need be)
 * an icon style manager and associated data in passing.
 *
 * Upon initialisation, this controller will open its window, put it at the
 * front of the normal stack and make it the key window.
 *
 * In:  ( NSString * ) windowNibName
 *      Name of the NIB containing this controller's window.
 *
 * Out: ( id )
 *      This instance ("self").
\******************************************************************************/

- ( id ) initWithWindowNibName: ( NSString * ) windowNibName
{
    if ( ( self = [ super initWithWindowNibName: windowNibName ] ) )
    {
        iconStyleManager     = [ IconStyleManager iconStyleManager     ];
        managedObjectContext = [ iconStyleManager managedObjectContext ];
        managedObjectModel   = [ iconStyleManager managedObjectModel   ];

        [ [ self window ] center ];
        [ [ self window ] makeKeyAndOrderFront: nil ];
    }

    return self;
}

/******************************************************************************\
 * -initWindowContents
 *
 * Initialise the window contents, such as the table view and action buttons.
 *
 * See also: -initWithWindowNibName:
 *           -awakeFromNib
\******************************************************************************/

- ( void ) initWindowContents
{
    [ removeButton      setEnabled: NO ];
    [ stylesSubMenuItem setEnabled: NO ];

    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( folderListSelectionChanged: )
                                                    name: NSTableViewSelectionDidChangeNotification
                                                  object: folderList ];

    /* Set up supported user interaction operations */

    [ folderList registerForDraggedTypes: @[ NSFilenamesPboardType, NSINDEXSET_ON_PBOARD ] ];

	[ folderList setDraggingSourceOperationMask: NSDragOperationLink forLocal: NO  ];
	[ folderList setDraggingSourceOperationMask: NSDragOperationMove forLocal: YES ];

    [ folderList setAllowsColumnSelection: NO ];

    /* Since we've a shared CoreData managed object context by now (see
     * "-initWithWindowNibName:"), we can use it to listen for changes to
     * the icon style list. If a style is deleted when in use, for example,
     * the folder list table view breaks badly unless we change to another
     * style. This can happen manually or because a user deletes a SlipCover
     * case definition which was in use by a user-defined icon style.
     */

    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( iconStyleListChanged: )
                                                    name: NSManagedObjectContextObjectsDidChangeNotification
                                                  object: managedObjectContext ];
}

/******************************************************************************\
 * -initOpenPanel
 *
 * Initialise the file dialogue box used to add folders to the table view
 * in the main window. Store the initialised object in "openPanel". This
 * object must be released when no longer required.
 *
 * See also: -addButtonPressed
\******************************************************************************/

- ( void ) initOpenPanel
{
    NSString * home = [ @"~" stringByExpandingTildeInPath ];

    openPanel = [ NSOpenPanel openPanel ];

    [ openPanel setMessage: NSLocalizedString( @"Choose folders to be given new icons", @"Message shown in the Open Panel used for folder addition" ) ];
    [ openPanel setPrompt:  NSLocalizedString( @"Add",                                  @"Button text in the Open Panel used for folder addition"   ) ];

    [ openPanel setCanChooseFiles:          NO  ];
    [ openPanel setCanChooseDirectories:    YES ];
    [ openPanel setCanCreateDirectories:    NO  ];
    [ openPanel setAllowsMultipleSelection: YES ];
    [ openPanel setResolvesAliases:         YES ];

    [ openPanel setDirectoryURL: [ NSURL fileURLWithPath: home
                                             isDirectory: YES ] ];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Inter-process communication
//------------------------------------------------------------------------------

/******************************************************************************\
 * -doCommsThread
 *
 * This method is run inside the thread which handle distant connections from
 * the command-line tool during folder processing.
 *
 * See also: awakeFromNib
\******************************************************************************/

- ( void ) doCommsThread
{
    @autoreleasepool
    {
        NSConnection * connection = [ NSConnection new ];

        [ connection setRootObject: self ];
        [ connection registerName: APP_SERVER_CONNECTION_NAME ];

        [ [ NSRunLoop currentRunLoop ] run ];
    }
}

/******************************************************************************\
 * -folderProcessedSuccessfully:
 *
 * FolderProcessNotification: Call when a folder has had its icon successfully
 * applied. Pass the full POSIX path of the folder. Returns YES if the worker
 * thread has had cancellation requested; the caller should exit as soon as
 * possible. Returns NO if the caller can continue normally.
 *
 * In:  ( NSString * ) fullPOSIXPath
 *      Full POSIX path of a folder which has just had an icon applied.
 *
 * Out: If YES, the caller should exit as soon as possible (cancellation). If
 *      NO, the caller should continue normally.
\******************************************************************************/

- ( BOOL ) folderProcessedSuccessfully: ( NSString * ) fullPOSIXPath
{
    [ self performSelectorOnMainThread: @selector( advanceProgressBarFor: )
                            withObject: fullPOSIXPath
                         waitUntilDone: NO ];

    return [ workerThread isCancelled ];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Task initiation and the modal progress panel
//------------------------------------------------------------------------------

/******************************************************************************\
 * -showProgressPanelWithMessage:andAction:andData:
 *
 * Show a modal progress panel and perform some action in a thread. When the
 * thread is cancelled or finishes its task, it MUST ask the main thread to
 * call "[NSApp abortModal]" so that the modal run loop can exit, *AFTER* it
 * has shut down its autorelease pool (if it created one).
 *
 * In: ( NSString * ) message
 *     String shown above the progress bar (e.g. "Adding folders...");
 *
 *     ( SEL ) actionSelector
 *     Selector to invoke within the worker thread, which must be of the
 *     signature "- ( void ) actionSelector: ( id ) actionSelectorData";
 *
 *     ( id ) actionSelectorData
 *     User data parameter passed to action selector.
\******************************************************************************/

- ( void ) showProgressPanelWithMessage: ( NSString * ) message
                              andAction: ( SEL        ) actionSelector
                                andData: ( id         ) actionSelectorData
{
    /* Set up the progress indicator panel */
    
    [ progressIndicatorLabel setStringValue: message ];

    [ progressIndicator setIndeterminate: YES  ];
    [ progressIndicator startAnimation:   self ];

    [ progressStopButton setEnabled: YES ];
    [ progressStopButton setTitle: NSLocalizedString( @"Stop", @"Title shown in progress panel 'stop' button when the progress panel is first shown" ) ];

    /* Start the modal run loop before the worker thread, to avoid possible
     * race conditions where the worker manages to finish before the panel
     * has opened and/or the modal run loop been entered.
     */

    [ NSApp beginSheet: progressIndicatorPanel
        modalForWindow: [ self window ]
         modalDelegate: nil   
        didEndSelector: nil   
           contextInfo: nil ];

    /* Kick off the task in an independent thread so the GUI can still
     * respond within its (modal) run loop. Almost nothing can happen to
     * the GUI while this thread runs, avoiding most issues with reentrancy
     * and thread safety.
     *
     * http://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html%23//apple_ref/doc/uid/10000057i-CH12-SW1
     */

    workerThread = [ [ NSThread alloc ] initWithTarget: self
                                              selector: actionSelector
                                                object: actionSelectorData ];
    [ workerThread start ];

    /* Now wait for the modal session to end either by the user clicking on
     * the progress panel's 'Stop' button or via the task in the timer
     * cancelling it. This call does not return as long as the modal run
     * loop is running.
     */

    [ NSApp runModalForWindow: progressIndicatorPanel ];

    /* Once execution continues at this point, the modal run loop has been
     * ended by the worker thread asking the main thread to send 'stopModal'
     * to 'NSApp'.
     */


    /* Close the progress panel */

    [ NSApp endSheet: progressIndicatorPanel ];

    [ progressIndicator      stopAnimation: self ];
    [ progressIndicatorPanel orderOut:      self ];

    /* Whether processing icons or adding subdirectories, the folder list can
     * be updated; it's harmless to call this if not (just wastes CPU cycles at
     * a very "non-critical" moment) and essential to call this if so.
     */

    [ folderList reloadData ];
}

/******************************************************************************\
 * -closeProgressPanel:
 *
 * Action sent by the 'Stop' button in the modal progress panel. Changes the
 * button so it is no longer enabled and says 'Stopping...', then cancels the
 * worker thread and does nothing else - the rest is up to the thread.
 *
 * In:       ( id ) sender
 *           Sender of the message (ignored).
 *
 * See also: -showProgressPanelWithMessage:andAction:andData:
\******************************************************************************/

- ( IBAction ) closeProgressPanel: ( id ) sender
{
    [ progressStopButton setEnabled: NO ];
    [ progressStopButton setTitle: NSLocalizedString( @"Stopping...", @"Title shown in progress panel 'stop' button once the button has been clicked upon and worker thread cancellation is underway" ) ];
    [ workerThread cancel ];
}

/******************************************************************************\
 * -considerInsertingSubfoldersOf:
 *
 * If user defaults say that sub-folders should be added, then add them,
 * showing a modal progress panel during the addition.
 *
 * To make sure that any existing modal operations have already finished, the
 * operation is run on an NSTimer which fires as soon as possible after this
 * method is invoked.
 *
 * In:       ( NSDictionary * ) parentFolders
 *           A dictionary with a key of "urls", in which case the value is an
 *           NSArray of file URLs, *OR* a key of "strings", in which case the
 *           value is an NSArray of NSString values giving the POSIX path of
 *           each parent folder. If an additional key "firstIndex" is present,
 *           its value is as "unsigned long" in an NSNumber, giving the first
 *           index at which addition will commence (e.g. 0 would start at index
 *           0, shuffling all other items below it downwards) - otherwise,
 *           folders are added to the end of the list;
 *
 *           It is assumed that the parent folders are already added; only sub-
 *           folders will be added thereafter, excluding hidden items, packages
 *           (e.g. ".app" bundles) or package contents.
 *
 * See also: -startInsertingSubfoldersOnTimer:
\******************************************************************************/

- ( void ) considerInsertingSubfoldersOf: ( NSDictionary * ) parentFolders
{
    if ( [ [ NSUserDefaults standardUserDefaults ] boolForKey: @"addSubFolders" ] == YES )
    {
        [ NSTimer scheduledTimerWithTimeInterval: 0
                                          target: self
                                        selector: @selector( insertSubfoldersOnTimer: )
                                        userInfo: parentFolders
                                         repeats: NO ];
    }
}

/******************************************************************************\
 * -startInsertingSubfoldersOnTimer:
 *
 * Start inserting sub-folders; see "-considerInsertingSubfoldersOf:" for
 * details. Do not call directly.
 *
 * In:       ( NSTimer * ) theTimer
 *           Timer used to invoke this method; its user info must be set to the
 *           dictionary as described for "-considerInsertingSubfoldersOf:".
 *
 * See also: -considerInsertingSubfoldersOf:
\******************************************************************************/

- ( void ) insertSubfoldersOnTimer: ( NSTimer * ) theTimer
{
    [ self showProgressPanelWithMessage: NSLocalizedString( @"Adding sub-folders...", @"Message shown in progress panel when adding sub-folders" )
                              andAction: @selector( addSubFoldersOf: )
                                andData: [ theTimer userInfo ] ];
}

/******************************************************************************\
 * -addSubFoldersOf:
 *
 * Worker thread suitable for use during a modal run loop. Adds sub-folders
 * of a given array of parent folders to the end of the overall folder list.
 *
 * Invoke via NSThread's "-initWithTarget:selector:object" during modal run
 * loops only.
 *
 * Conforms to the requirements described by
 * "-showProgressPanelWithMessage:andAction:andData:" and correctly invoked
 * through the actions of "-considerInsertingSubfoldersOf".
 *
 * When the thread finishes adding folders or is cancelled, it causes
 * "-abortModal" to be sent to NSApp in the main thread.
 *
 * In:       ( NSDictionary * ) parentFolders
 *           As described for "-considerInsertingSubfoldersOf:".
 *
 * See also: -showProgressPanelWithMessage:andAction:andData:
 *           -considerInsertingSubfoldersOf:
\******************************************************************************/

- ( void ) addSubFoldersOf: ( NSDictionary * ) parentFolders
{
    @autoreleasepool
    {
        NSArray    * parentFolderArray     = parentFolders[ @"urls"       ];
        NSNumber   * firstIndex            = parentFolders[ @"firstIndex" ];
        BOOL         isURLs                = YES;
        NSUInteger   startRow, currentRow;

        if ( firstIndex != nil ) startRow = currentRow = [ firstIndex unsignedLongValue ];
        else                     startRow = currentRow = [ tableContents count ];

        if ( parentFolderArray == nil )
        {
            parentFolderArray = parentFolders[ @"strings" ];
            isURLs            = NO;
        }

        for ( id parentItem in parentFolderArray )
        {
            /* For convenience, the folder array can specify paths as POSIX path
             * strings or URLs. Due to the NSFileManager API not providing a way
             * to enumerate based on string with options, only by URL with options,
             * we have to convert any strings into URLs.
             */

            NSURL * parentPath;

            if ( isURLs ) parentPath = ( NSURL * ) parentItem;
            else          parentPath = [ NSURL fileURLWithPath: ( NSString * ) parentItem
                                                   isDirectory: YES ];

            /* We're not interested in enumerating package contents or hidden
             * files; we do want to know if something is a directory.
             */

            NSFileManager         * fileManager = [ [ NSFileManager alloc ] init ]; /* Since [NSFileManager defaultManager] is not thread-safe; see Apple docs */
            NSDirectoryEnumerator * dirEnum =
            [
                fileManager enumeratorAtURL: parentPath
                 includingPropertiesForKeys: @[ NSURLIsDirectoryKey, NSURLIsPackageKey ]
                                    options: NSDirectoryEnumerationSkipsHiddenFiles |
                                             NSDirectoryEnumerationSkipsPackageDescendants
                               errorHandler: nil
            ];

            for ( NSURL * url in dirEnum )
            {
                /* Keep checking for thread cancellation in case the user hits
                 * the 'stop' button in the progress panel.
                 */
                 
                if ( [ [ NSThread currentThread ] isCancelled ] == YES ) break;

                /* Don't add packaged folders */

                NSNumber * isDirectory;
                NSNumber * isPackage;
                NSError  * error = nil;

                [ url getResourceValue: &isPackage
                                forKey: NSURLIsPackageKey
                                 error: &error ];

                if ( error == nil && [ isPackage boolValue ] == YES )
                {
                    continue;
                }

                /* Only add (not packaged, see above) folders */

                [ url getResourceValue: &isDirectory
                                forKey: NSURLIsDirectoryKey
                                 error: &error ];

                if ( error == nil && [ isDirectory boolValue ] == YES )
                {
                    /* Folder list additions can cause GUI updates and these
                     * are only truly 'safe' if done in the main thread.
                     *
                     * This slows things down a fair bit, but generally the
                     * bottleneck is still the filesystem, not the CPU.
                     */

                    if ( firstIndex != nil )
                    {
                        NSDictionary * dictionary =
                        @{
                          @"path":  [ url path ],
                          @"index": @( currentRow )
                        };

                        [ self performSelectorOnMainThread: @selector( insertFolderByDictionary: )
                                                withObject: dictionary
                                             waitUntilDone: YES ];
                    }
                    else
                    {
                        [ self performSelectorOnMainThread: @selector( addFolder: )
                                                withObject: [ url path ]
                                             waitUntilDone: YES ];
                    }

                    currentRow ++;
                }            
            }

            /* Keep checking for thread cancellation in this outer loop too, again
             * in case the user hits the 'stop' button in the progress panel - we
             * may have just dropped out of the inner loop above because of that.
             */
             
            if ( [ [ NSThread currentThread ] isCancelled ] == YES ) break;
        }

        /* Build ranges for the array start to just before the insertion row;
         * for the inserted rows; and for just after the inserted rows to the
         * end of the array. Then amalgamate the first and last of those so
         * we have an array of indices of 'old' and 'new' items.
         */

        NSMutableIndexSet * beforeAddition = [ NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange( 0, startRow ) ];
        NSIndexSet        * duringAddition = [ NSIndexSet        indexSetWithIndexesInRange: NSMakeRange( startRow, currentRow - startRow ) ];
        NSIndexSet        * afterAddition  = [ NSIndexSet        indexSetWithIndexesInRange: NSMakeRange( currentRow, [ tableContents count ] - currentRow ) ];

        [ beforeAddition addIndexes: afterAddition ];

        /* Use these results to call the duplicates removal routine, then tell
         * the folder list table view about the changes.
         */

        [ self removeDuplicatesFromIndices: beforeAddition
                           comparedAgainst: duringAddition ];

    } // @autoreleasepool

    /* Tell the main thread to finish modal operation. Since this is happening
     * outside the modal window's modal run loop, we must use "abortModal"
     * rather than "stopModal", else the modal session won't end in the way
     * we expect (specifically the panel stays open until 'some event' causes
     * it to "realise" it should have closed, e.g. waving the mouse over it).
     *
     * When the modal loop ends, the code will "-release" the object which
     * represents this thread. We could be terminated at any point. Thus, that
     * action must be the last thing we do here. But that in turn means the
     * autorelease pool has to be dealt with first and so, we can't just do
     * "[NSApp abortModal]" as this leads to various autorelease objects such
     * as "NSEvent" being generated - which are thus warned about at the
     * console and leaked, as there is no prevailing pool anymore.
     *
     * The solution is simple enough; just ask the main thread to do the work,
     * as its autorelease pool is ready and waiting.
     */

    [ NSApp performSelectorOnMainThread: @selector( abortModal )
                             withObject: nil
                          waitUntilDone: NO ];
}

/******************************************************************************\
 * -startButtonPressed:
 *
 * Create and add icons for all folders in the folder list.
 *
 * In: ( id ) sender
 *     Object sending this message (ignored).
\******************************************************************************/

- ( IBAction ) startButtonPressed: ( id ) sender
{
    ( void ) sender;

    [ self showProgressPanelWithMessage: NSLocalizedString( @"Adding folder icons...", @"Message shown in progress panel when adding custom folders icons" )
                              andAction: @selector( createFolderIcons: )
                                andData: tableContents ];
}

/******************************************************************************\
 * -createFolderIcons:
 *
 * Worker thread suitable for use during a modal run loop. Creates and adds
 * folder icons from a folder list.
 *
 * Invoke via NSThread's "-initWithTarget:selector:object" during modal run
 * loops only.
 *
 * Conforms to the requirements described by
 * "-showProgressPanelWithMessage:andAction:andData:" and correctly invoked
 * through the actions of "-startButtonPressed".
 *
 * When the thread finishes adding icons or is cancelled, it causes
 * "-abortModal" to be sent to NSApp in the main thread.
 *
 * In:       ( NSArray * ) folderList
 *           Array of NSDictionary objects with key "path" giving the full
 *           POSIX path of the folder to process and "style" pointing to a
 *           IconStyle object which describes the style of icon to greate.
 *           Internally, a copy is used; the given array is not modified.
 *
 * See also: -showProgressPanelWithMessage:andAction:andData:
 *           -startButtonPressed:
\******************************************************************************/

- ( void ) createFolderIcons: ( NSArray * ) constArrayOfDictionaries
{
    globalSemaphoreInit();

    @autoreleasepool
    {
        NSUserDefaults * standardUserDefaults  = [ NSUserDefaults standardUserDefaults ];
        NSArray        * coverArtFilenames     = [ standardUserDefaults arrayForKey: @"coverArtFilenames" ];
        BOOL             includeColourLabels   = [ standardUserDefaults boolForKey: @"colourLabelsIndicateCoverArt" ];

        if ( [ coverArtFilenames count ] == 0 )
        {
            coverArtFilenames = @[ @"cover", @"folder" ];
        }

        /* Take a copy of and sort the array, grouping it by icon style. Using a
         * copy avoids thread safety issues / cross-thread communication delays
         * with trying to update 'tableContents' (and the related table view in
         * 'folderList') in the main thread. It also means we can modify the array
         * without disturbing the GUI - handy if we get cancelled. Of course on
         * the downside, it wastes RAM and CPU cycles to do the copy.
         */

        NSMutableArray * arrayOfDictionaries = [ NSMutableArray arrayWithArray: constArrayOfDictionaries ];

        [
            arrayOfDictionaries sortUsingComparator: ^ ( NSDictionary * obj1, NSDictionary * obj2 )
            {
                IconStyle * s1 = obj1[ @"style" ];
                IconStyle * s2 = obj2[ @"style" ];

                return [ [ [ [ s1 objectID ] URIRepresentation ] absoluteString ]
                compare: [ [ [ s2 objectID ] URIRepresentation ] absoluteString ] ];
            }
        ];

        /* Avoid code duplication below by using this little block as a task
         * runner function. It's passed the path of the CLI tool and an alloc'd
         * mutable array of arguments. It runs the CLi tool with those arguments,
         * calls "-release" on the arguments and waits for the task to exit.
         *
         * Returns EXIT_SUCCESS if everything worked, else EXIT_FAILURE for any
         * problems.
         */

        int ( ^ taskRunner ) ( NSString *, NSMutableArray * ) = ^ ( NSString * path, NSMutableArray * arguments )
        {
            /* We just sit here and wait until the task exits for any reason. The
             * task can talk back to us through the communications thread (see e.g.
             * "-doCommsThread"). It asks us if there has been early cancellation
             * using the protocol implemented by that communications thread and
             * will exit if so, allowing this thread to resume processing and
             * handle the cancellation condition itself.
             */

/* Establish default parameters which command line arguments can override */

IconParameters * params = [ [ IconParameters alloc ] init ];

params.commsChannel           = nil;
params.previewMode            = NO;

params.slipCoverCase          = nil;
params.crop                   = NO;
params.border                 = NO;
params.shadow                 = NO;
params.rotate                 = NO;
params.maxImages              = 4;
params.showFolderInBackground = StyleShowFolderInBackgroundForOneOrTwoImages;
params.singleImageMode        = NO;
params.useColourLabels        = NO;
params.coverArtNames          =
[
    NSMutableArray arrayWithObjects: @"folder",
                                     @"cover",
                                     nil
];

NSUInteger argi = 0;
NSUInteger argc = [ arguments count ];

while ( true )
{
    /* Simple boolean switches */

    NSString * arg = ( NSString * ) arguments[ argi ];

    if ( [ arg length ] <= 2 || [ arg compare: @"--" options: 0 range: NSMakeRange( 0, 2 ) ] != NSOrderedSame )
    {
        break;
    }

    if      ( [ arg isEqualToString: @"--crop"   ] ) params.crop            = YES;
    else if ( [ arg isEqualToString: @"--border" ] ) params.border          = YES;
    else if ( [ arg isEqualToString: @"--shadow" ] ) params.shadow          = YES;
    else if ( [ arg isEqualToString: @"--rotate" ] ) params.rotate          = YES;
    else if ( [ arg isEqualToString: @"--single" ] ) params.singleImageMode = YES;
    else if ( [ arg isEqualToString: @"--labels" ] ) params.useColourLabels = YES;

    /* Numerical parameters */

    else if ( [ arg isEqualToString: @"--maximages"  ] && ( ++ argi ) < argc ) params.maxImages              = [ arguments[ argi ] intValue ];
    else if ( [ arg isEqualToString: @"--showfolder" ] && ( ++ argi ) < argc ) params.showFolderInBackground = [ arguments[ argi ] intValue ];

    /* String parameters */
    
    else if ( [ arg isEqualToString: @"--communicate" ] && ( ++ argi ) < argc )
    {
        /* The public usage string does not print this argument out as it
         * is for internal use between the CLI tool and application. The
         * application provides its NSConnection server name here.
         */

        params.commsChannel = arguments[ argi ];
    }

    /* SlipCover definition - this one is more complicated as we have to
     * generate the case definition from the name and store the definition
     * reference in the icon style parameters.
     */

//    else if ( [ arg isEqualToString: @"--slipcover" ] && ( ++ argi ) < argc )
//    {
//        NSString       * requestedName   = [ NSString stringWithUTF8String: argv[ arg ] ];
//        CaseDefinition * foundDefinition = [ SlipCoverSupport findDefinitionFromName: requestedName ];
//
//        if ( foundDefinition == nil )
//        {
//            printVersion();
//            printf( "SlipCover case name '%s' is not recognised.\n", argv[ arg ] );
//            return EX_USAGE;
//        }
//
//        params.slipCoverCase = foundDefinition;
//    }

    /* Array - the second parameter after the switch is the number of
     * items, followed by the items themselves.
     */
    
    else if ( [ arg isEqualToString: @"--coverart" ] && ( argi + 2 ) < argc )
    {
        int              count = [ arguments[ ++ argi ] intValue ];
        NSMutableArray * array = [ NSMutableArray arrayWithCapacity: count ];

        for ( int i = 0; i < count && argi + 1 < argc; i ++ )
        {
            ++ argi; /* Must be careful to leave 'arg' pointing at last "used" argument */
            [ array addObject: arguments[ argi ] ];
        }

        params.coverArtNames = array;
    }

    else break; /* Assume a folder name */

    ++ argi;
}

///* If parameters are out of range or we've run out of arguments so no
// * folder filenames were supplied, complain.
// */
//
//if ( arg >= argc || params.maxImages < 1 || params.maxImages > 4 || params.showFolderInBackground > StyleShowFolderInBackgroundAlways )
//{
//    printVersion();
//    printHelp();
//    return EXIT_FAILURE;
//}

/* Prerequisites */

NSOperationQueue * queue = [ [ NSOperationQueue  alloc ] init ];

/* Process pathnames and add Grand Central Dispatch operations for each */

for ( int i = argi; i < argc; i ++ )
{
    NSString * fullPosixPath = arguments[ i ];

    ConcurrentPathProcessor * processThisPath =
    [
        [ ConcurrentPathProcessor alloc ] initWithPath: fullPosixPath
                                         andBackground: nil
                                         andParameters: params
    ];

    NSArray * oneOp = @[ processThisPath ];
    [ queue addOperations: oneOp waitUntilFinished: NO ];
}

[ queue waitUntilAllOperationsAreFinished ];

//return ( globalErrorFlag == YES ) ? EXIT_FAILURE : EXIT_SUCCESS;

return EXIT_SUCCESS;


//            NSTask * task = [ NSTask launchedTaskWithLaunchPath: path
//                                                      arguments: arguments ];
//            [ task waitUntilExit ];
//
//            /* Success or failure? Would like to return a BOOL but the compiler
//             * insists that such code is actually returning an int, yet refuses
//             * to recognise that in the same way if the block is declared as
//             * returning a BOOL rather than an int. To keep it simple, we just
//             * return something which is semantically really defined as a simple
//             * int; an old-style exit status.
//             */
//
//            return ( [ task terminationReason ] == NSTaskTerminationReasonExit &&
//                     [ task terminationStatus ] == EXIT_SUCCESS )
//                     ?
//                     EXIT_SUCCESS
//                     :
//                     EXIT_FAILURE;
        };

        /* Process folders in batches grouped by icon style, so that we can pass a
         * long command line with multiple folders simultaneously specified in one
         * go to the command line tool. This allows it to employ whatever parallel
         * processing tricks it can.
         *
         * Mindful of command line length limits (AFAII ~256K on Mac OS 10.6) as
         * well as general sanity in attempting to compile truly vast command line
         * strings and to avoid potentially large peak RAM overheads, no more than
         * 144 (divides cleanly between 2, 4, 6, 8, 12, 16... cores) folders will
         * be passed in at one time before deliberately grouping the next set of
         * folders again.
         *
         * To keep things simple, don't worry about edge cases such as the
         * ineffiency of processing 144 folders, only to find one remaining 145th
         * item using that style and having to process it individually. This isn't
         * common enough to be worth the effort and besides, icon creation just
         * isn't that time-critical a process!
         */

        NSString       * toolPath      = [ ApplicationSupport auxiliaryExecutablePathFor: @"addfoldericons" ];
        NSMutableArray * toolArgs      = nil;
        IconStyle      * currentStyle  = nil;
        NSUInteger       addedCount    = 0;
        int              taskStatus    = EXIT_SUCCESS;

        while ( [ arrayOfDictionaries count ] > 0 )
        {
            /* The grouping loop runs quickly so doesn't check for cancellation.
             * That's done whenever the icon generator task is run.
             */

            NSDictionary * folder = [ arrayOfDictionaries lastObject ];
            NSString     * path   = folder[ @"path"  ];
            IconStyle    * style  = folder[ @"style" ];

            if ( [ currentStyle objectID ] != [ style objectID ] )
            {
                /* First, is there an old group to now process? */

                if ( addedCount > 0 )
                {
                    taskStatus = taskRunner( toolPath, toolArgs ); /* taskRunner() deals with calling [toolArgs release] */

                    /* Did that fail? */
                    
                    if ( taskStatus == EXIT_FAILURE ) break;

                    /* We may have been cancelled while the task was running (see
                     * also comments within the definition of the 'taskRunner'
                     * block above).
                     */

                    if ( [ [ NSThread currentThread ] isCancelled ] == YES ) break;
                }

                /* Next, start the new group */

                addedCount   = 0;
                currentStyle = style;
                toolArgs   = [ style allocArgumentsUsing: coverArtFilenames
                              withColourLabelsAsCoverArt: includeColourLabels ];
            }

            [ toolArgs addObject: path ];
            [ arrayOfDictionaries removeLastObject ];
            addedCount ++;

            /* If we've added 24 folders, reset the current style to provoke the
             * start of a new group on the next trip around the loop. It is
             * important to check the thread cancellation quite often without
             * queueing too much in Grand Central - Snow Leopard shows no issues
             * but on Lion things seem to lock up (GCD just never completes all
             * of its operations).
             *
             * 24 concurrent operations should easily soak a 12-core machine.
             */

            if ( addedCount >= 24 ) currentStyle = nil;
        }

        if ( [ [ NSThread currentThread ] isCancelled ] == NO )
        {
            /* Anything left over for processing as a result of the last group
             * encountered in the loop above? No need to check for cancellation
             * after this, since we're going to exit anyway.
             */

            if ( addedCount > 0 )
            {
                taskStatus = taskRunner( toolPath, toolArgs ); /* taskRunner() deals with calling [toolArgs release] */
            }
        }

        /* If things went wrong tell the user in a modal alert opened from within
         * this modal loop, so the progress panel is still visible as an indication
         * of continuity between the addition process and the alert.
         *
         * The shell tool exits and flags an error if the controlling thread is
         * cancelled (discovered via the FolderProcessNotification protocol), so
         * only report errors for non-cancelled cases. The edge-case of a thread
         * being cancelled just as a real error happened to arise does result in
         * a "missed" error, but since the user cancelled the operation anyway we
         * don't really care about that.
         *
         * If things went *right*, ask the main thread to consider removing folders
         * from the folder list (depending on preferences it may or may not do so).
         */

        if ( [ [ NSThread currentThread ] isCancelled ] == NO )
        {
            if ( taskStatus == EXIT_FAILURE )
            {
                [ self performSelectorOnMainThread: @selector( showAdditionFailureAlert )
                                        withObject: nil
                                     waitUntilDone: YES ];
            }
            else
            {
                [ self performSelectorOnMainThread: @selector( considerEmptyingFolderList )
                                        withObject: nil
                                     waitUntilDone: YES ];
            }
        }

    } // @autoreleasepool

    /* See "-addSubFoldersOf:" for the rationale behind this next call */

    [ NSApp performSelectorOnMainThread: @selector( abortModal )
                             withObject: nil
                          waitUntilDone: NO ];
}

/******************************************************************************\
 * -advanceProgressBarFor:
 *
 * Note that a folder with the given full POSIX path has been processed
 * successfully. The modal progress panel's progress indicator is advanced
 * (and lazy-initialised to a determinate state on the first call).
 *
 * Invoke within the main processing thread only.
 *
 * In:       ( NSString * ) fullPOSIXPath
 *           Full POSIX path of the folder which was successfully processed.
 *
 * See also: -doCommsThread
 *           -folderProcessedSuccessfully:
\******************************************************************************/

- ( void ) advanceProgressBarFor: ( NSString * ) fullPOSIXPath
{
    ( void ) fullPOSIXPath;

    /* The progress indicator is only changed to a 'determinate' state when
     * the first message arrives from the command line tool telling us about
     * a folder that was processed.
     */

    if ( [ progressIndicator isIndeterminate ] )
    {
        [ progressIndicator setIndeterminate: NO ];
        [ progressIndicator setMinValue: 0 ];
        [ progressIndicator setMaxValue: [ tableContents count ] ];
        [ progressIndicator setDoubleValue: 0 ];
    }

    [ progressIndicator incrementBy: 1 ];
}

/******************************************************************************\
 * -clearButtonPressed:
 *
 * Remove custom icons from all folders in the folder list.
 *
 * In: ( id ) sender
 *     Object sending this message (ignored).
\******************************************************************************/

- ( IBAction ) clearButtonPressed: ( id ) sender
{
    ( void ) sender;

    NSAlert * alert =
    [
        NSAlert alertWithMessageText: NSLocalizedString( @"Really Remove Icons?", @"Title shown in alert asking if folder icons should really be removed" )
                       defaultButton: NSLocalizedString( @"Cancel", @"'Cancel' button in alert asking if folder icons should be removed" )
                     alternateButton: NSLocalizedString( @"Remove Icons", @"'Yes, remove icons' button shown in alert asking if folder icons should be removed" )
                         otherButton: nil
           informativeTextWithFormat: NSLocalizedString( @"Are you sure you want to remove custom icons from the folders in the list?", @"Question shown in alert asking if folder icons should really be removed" )
    ];

    /* Run the alert box and only add styles if asked to do so */

    if ( [ alert runModal ] == NSAlertAlternateReturn )
    {
        [ self showProgressPanelWithMessage: NSLocalizedString( @"Removing folder icons...", @"Message shown in progress panel when removing custom folders icons" )
                                  andAction: @selector( removeFolderIcons: )
                                    andData: tableContents ];
    }
}

/******************************************************************************\
 * -removeFolderIcons:
 *
 * Worker thread suitable for use during a modal run loop. Removes custom
 * folder icons from a folder list.
 *
 * Invoke via NSThread's "-initWithTarget:selector:object" during modal run
 * loops only.
 *
 * Conforms to the requirements described by
 * "-showProgressPanelWithMessage:andAction:andData:" and correctly invoked
 * through the actions of "-clearButtonPressed".
 *
 * When the thread finishes removing icons or is cancelled, it causes
 * "-abortModal" to be sent to NSApp in the main thread.
 *
 * In:       ( NSArray * ) folderList
 *           Array of NSDictionary objects with key "path" giving the full
 *           POSIX path of the folder to process and "style" pointing to a
 *           IconStyle object which describes the style of icon to greate.
 *           Internally, a copy is used; the given array is not modified.
 *
 * See also: -showProgressPanelWithMessage:andAction:andData:
 *           -startButtonPressed:
\******************************************************************************/

- ( void ) removeFolderIcons: ( NSArray * ) constArrayOfDictionaries
{
    @autoreleasepool
    {
        NSWorkspace * workspace = [ NSWorkspace sharedWorkspace ];

        /* No attempt is made to run this in parallel as it isn't clear if
         * NSWorkspace is sufficiently re-entrant/thread-safe and it runs
         * very quickly anyway.
         */

        for ( NSDictionary * folder in constArrayOfDictionaries )
        {
            NSString * path = folder[ @"path" ];
                
            [ workspace setIcon: nil forFile: path options: 0 ];
            if ( [ [ NSThread currentThread ] isCancelled ] == YES ) break;

            [ self performSelectorOnMainThread: @selector( advanceProgressBarFor: )
                                    withObject: path
                                 waitUntilDone: YES ];
        }

        [ self performSelectorOnMainThread: @selector( considerEmptyingFolderList )
                                withObject: nil
                             waitUntilDone: YES ];

    } // @autoreleasepool

    /* See "-addSubFoldersOf:" for the rationale behind this next call */

    [ NSApp performSelectorOnMainThread: @selector( abortModal )
                             withObject: nil
                          waitUntilDone: NO ];
}

/******************************************************************************\
 * -considerEmptyingFolderList
 *
 * Call if folder processing has been successful. If the preferences say so the
 * folder list table contents will be emptied. It is up to the caller to ask
 * the folder list table view to reload its data ("[folderList reloadData]")
 * in some appropriate context afterwards.
 *
 * In practice this is intended only to called from the main thread via the
 * folder processing thread as part of the modal processing loop, which takes
 * care of asking for a data reload in passing itself.
\******************************************************************************/

- ( void ) considerEmptyingFolderList
{
    if ( [ [ NSUserDefaults standardUserDefaults ] boolForKey: @"emptyListIfSuccessful" ] == YES )
    {
        [ tableContents removeAllObjects ];
    }
}

/******************************************************************************\
 * -showAdditionFailureAlert
 *
 * Call if folder processing failed. Raises an NSAlert warning the user that
 * something went wrong. This is done in a separate method so that a processing
 * thread can ask to call here in the main thread, since NSAlert does not
 * support being run from any other thread context.
\******************************************************************************/

- ( void ) showAdditionFailureAlert
{
    NSRunCriticalAlertPanel
    (
        NSLocalizedString( @"Icon Addition Failure", @"Title of alert reporting a failure to add all icons" ),
        NSLocalizedString( @"One or more of the folder addition attempts failed. You could try again with the existing folder list, clear the folder list and try with a new set of folders, or add fewer folders at a time.", @"Message shown in alert reporting a failure to add all icons "),
        NSLocalizedString( @"Continue", @"Button shown in alert reporting a failure to add all icons" ),
        nil,
        nil
    );
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Folder Selection Handling
//------------------------------------------------------------------------------

/******************************************************************************\
 * -addFolder:
 *
 * Add the given path to the end of the table contents array with a default
 * icon style. The path must be for a folder (this is not checked here).
 *
 * Duplicates removal is left up to the caller.
 *
 * In:       ( NSString * ) path
 *           Path of folder to add.
 *
 * See also: -addFolder:withStyle:
 *           -insertFolder:atIndex
 *           -insertFolder:atIndex:withStyle:
 *           -removeDuplicatesFromIndices:comparedAgainst:
\******************************************************************************/

- ( void ) addFolder: ( NSString * ) path
{
    [ self insertFolder: path
                atIndex: [ tableContents count ] ];
}

/******************************************************************************\
 * -addFolder:withStyle:
 *
 * Add the given path to the end of the table contents array with the given
 * named icon style. The path must be for a folder (this is not checked here).
 *
 * Duplicates removal is left up to the caller.
 *
 * In:       ( NSString * ) path
 *           Path of folder to add;
 *
 *           ( IconStyle * ) style
 *           Icon style to assign to this folder.
 *
 * See also: -addFolder:
 *           -insertFolder:atIndex
 *           -insertFolder:atIndex:withStyle:
 *           -removeDuplicatesFromIndices:comparedAgainst:
\******************************************************************************/

- ( void ) addFolder: ( NSString * ) path withStyle: ( IconStyle * ) style
{
    [ self insertFolder: path
                atIndex: [ tableContents count ]
              withStyle: style ];
}

/******************************************************************************\
 * -insertFolder:atIndex:
 *
 * Insert the given path at the given index (any other items at or above this
 * index being shuffled up one) with a default icon style. The path must be
 * for a folder (this is not checked here).
 *
 * Duplicates removal is left up to the caller.
 *
 * In:       ( NSString * ) path
 *           Path of folder to add;
 *
 *           ( NSUInteger ) index
 *           Index at which to insert the new item.
 *
 * See also: -insertFolder:atIndex:WithStyle:
 *           -addFolder:
 *           -addFolder:withStyle:
 *           -removeDuplicatesFromIndices:comparedAgainst:
\******************************************************************************/

- ( void ) insertFolder: ( NSString * ) path atIndex: ( NSUInteger ) index
{
    [ self insertFolder: path
                atIndex: index 
              withStyle: [ iconStyleManager findDefaultIconStyle ] ];
}

/******************************************************************************\
 * -insertFolder:atIndex:withStyle:
 *
 * Insert the given path at the given index (any other items at or above this
 * index being shuffled up one) with the given named icon style. The path must
 * be for a folder (this is not checked here).
 *
 * Duplicates removal is left up to the caller.
 *
 * In:       ( NSString * ) path
 *           Path of folder to add;
 *
 *           ( NSUInteger ) index
 *           Index at which to insert the new item.
 *
 *           ( IconStyle * ) style
 *           Icon style to assign to this folder.
 *
 * See also: -insertFolder:atIndex:
 *           -addFolder:
 *           -addFolder:withStyle:
 *           -removeDuplicatesFromIndices:comparedAgainst:
 \******************************************************************************/

- ( void ) insertFolder: ( NSString * ) path atIndex: ( NSUInteger ) index withStyle: ( IconStyle * ) style
{
    NSMutableDictionary * record =
    [
        NSMutableDictionary dictionaryWithObjectsAndKeys: path,  @"path",
                                                          style, @"style",
                                                          nil
    ];

    [ tableContents insertObject: record atIndex: index ];
}

/******************************************************************************\
 * -insertFolderByDictionary:
 *
 * As "-insertFolder:atIndex:", but the path and index are specified in a
 * dictionary (see parameters list below). This is less efficient, but means
 * the two parameters can be specified in a single argument - useful if being
 * called from another thread by one of the "-performSelector..." family of
 * messages, for example.
 *
 * Duplicates removal is left up to the caller.
 *
 * In:       ( NSDictionary * ) dictionary
 *           Dictionary with an NSString pointer as the value for key "path",
 *           giving the path of the folder to add and an NSNumber pointer as
 *           the value for key "index", giving the index at which to insert the
 *           new item encoded into an NSNumber as an "unsigned long".
 *
 * See also: -insertFolder:atIndex:
 *           -insertFolder:atIndex:WithStyle:
 *           -removeDuplicatesFromIndices:comparedAgainst:
 *           -addSubfoldersOf:
\******************************************************************************/

- ( void ) insertFolderByDictionary: ( NSDictionary * ) dictionary
{
    NSString * path  = dictionary[ @"path"  ];
    NSNumber * index = dictionary[ @"index" ];

    [ self insertFolder: path
                atIndex: [ index unsignedLongValue ] ];
}

/******************************************************************************\
 * -removeDuplicatesFromIndices:comparedAgainst:
 *
 * Pass two pointers to NSIndexSet instances. The first describes indices in
 * 'tableContents' which are to be searched. The second describes indices in
 * 'tableContents' which are to be compared. If any items from the second set
 * of indices are found to have a match in the first set of indices, then the
 * matching item in the *first set* is deleted.
 *
 * A 'match' is defined as 'same value for the @"path" key'. Other keys in the
 * dictionaries are ignored. The "-compare:" message is used to match the path
 * strings.
 *
 * The returned autoreleased index set may be useful if you were maintaining
 * one or more indices which may have been altered by the deletions.
 *
 * In:       ( NSIndexSet * ) sourceBlock
 *           Indices describing items in 'tableContents' which are to be
 *           searched through and possibly removed;
 *
 *           ( NSIndexSet * ) matchBlock
 *           Indices describing items in 'tableContents' which are each
 *           compared to all the items in the source block (see above) and, if
 *           any matches are found, the matched item in the *source block* will
 *           be deleted.
 *
 * Out:      Autoreleased index set describing the indices that were deleted.
 *
 * See also: -insertFolder:atIndex:
 *           -insertFolder:atIndex:WithStyle:
 *           -removeDuplicatesFromIndices:comparedAgainst:
 *           -addSubfoldersOf:
\******************************************************************************/

- ( NSIndexSet * ) removeDuplicatesFromIndices: ( NSIndexSet * ) sourceBlock
                               comparedAgainst: ( NSIndexSet * ) matchBlock
{
    NSMutableIndexSet * duplicates = [ NSMutableIndexSet indexSet ];

    /* Match against the lower and upper blocks concurrently, adding the index
     * of any duplicate found into the 'duplicates' set. For each item in the
     * match block we have to scan the whole source block.
     */

    [
        matchBlock enumerateIndexesUsingBlock: ^ ( NSUInteger matchIndex, BOOL * stop )
        {
            NSDictionary * matchRecord = tableContents[ matchIndex ];
            NSString     * matchPath   = [ matchRecord valueForKey: @"path" ];

            NSUInteger found =
            [
                tableContents indexOfObjectWithOptions: NSEnumerationConcurrent
                                           passingTest: ^ ( id obj, NSUInteger index, BOOL * stop )
                {
                    /* Proceed on the basis that checking for an index in a set
                     * is comparatively fast, while extracting a string from a
                     * dictionary and comparing it to another string is
                     * comparatively slow. Only do the comparision if the index
                     * is within the source block range and has not been marked
                     * as a duplicate already.
                     */

                    if (
                           [ sourceBlock containsIndex: index ] == YES &&
                           [ duplicates  containsIndex: index ] == NO
                       )
                    {
                        NSDictionary * sourceRecord = ( NSDictionary * ) obj;
                        NSString     * sourcePath   = [ sourceRecord valueForKey: @"path" ];

                        if ( [ sourcePath compare: matchPath ] == NSOrderedSame )
                        {
                            *stop = YES;
                            return YES;
                        }
                    }

                    return NO;
                }
            ];

            if ( found != NSNotFound ) [ duplicates addIndex: found ];
        }
    ];

    /* Now remove all found duplicates in one go */

    [ tableContents removeObjectsAtIndexes: duplicates ];
    return duplicates;
}

/******************************************************************************\
 * -folderListSelectionChanged:
 *
 * Called via the default NSNotificationCenter when notification message is
 * "NSTableViewSelectionDidChangeNotification" sent by the folder list. Updates
 * other parts of the UI (e.g. disables the 'remove' button if no rows are
 * selected).
 *
 * In:       ( NSNotification * ) notification
 *           The notification details (ignored).
 *
 * See also: -removeButtonPressed:
\******************************************************************************/

- ( void ) folderListSelectionChanged: ( NSNotification * ) notification
{
    ( void ) notification;

    BOOL atLeastOneSelected = [ folderList numberOfSelectedRows ] != 0;

    [ removeButton      setEnabled: atLeastOneSelected ];
    [ stylesSubMenuItem setEnabled: atLeastOneSelected ];
}

/******************************************************************************\
 * -addButtonPressed:
 *
 * Handle clicks on the '+' (add) button - open the file dialogue box stored in
 * "openPanel".
 *
 * In:       ( id ) sender
 *           Sender (may be nil).
 *
 * See also: -initOpenPanel
 \******************************************************************************/

- ( IBAction ) addButtonPressed: ( id ) sender
{
	void ( ^ openPanelHandler ) ( NSInteger ) = ^ ( NSInteger result )
	{
        if ( result == NSFileHandlingPanelOKButton )
        {
            /* Take note of how many items are in the table to start with and
             * how many new items are to be added, then add them.
             */

            NSUInteger originalCount = [ tableContents      count ];
            NSUInteger additionCount = [ [ openPanel URLs ] count ];

            for ( NSURL * url in [ openPanel URLs ] )
            {
                NSString * pathBeingAdded = [ url path ];
                [ self addFolder: pathBeingAdded ];
            }

            /* We added the new items at the end, so we know the index ranges
             * of the old and new items easily. Call the duplicates removal
             * routine with this information.
             */

            [
                self removeDuplicatesFromIndices: [ NSIndexSet indexSetWithIndexesInRange: NSMakeRange( 0,             originalCount ) ]
                                 comparedAgainst: [ NSIndexSet indexSetWithIndexesInRange: NSMakeRange( originalCount, additionCount ) ]
            ];

            /* Tell the folder list about the changes, then consider adding
             * subfolders. A block of parent folders will be followed by a
             * block of subfolders; we don't try to mix them together. In
             * practice, this is often a much more useful approach as a set
             * of parent folders without icons, or with a different icon style,
             * can each contain a set of children which might all want to be
             * updated (e.g. folders of genres, containing folders of albums).
             * By dragging on the parents, the whole folder set is enumerated;
             * but because the parents are kept in one block, removing them so
             * that only the children are processed, or changing their styles,
             * is much easier. If parents and children ended up mixed in the
             * list, it would be much more fiddly for the user.
             */

            [ folderList reloadData ];
            [ self considerInsertingSubfoldersOf: @{ @"urls": [ openPanel URLs ] } ];
        }
	};

    [ openPanel beginSheetModalForWindow: [ self window ]
                       completionHandler: openPanelHandler ];
}

/******************************************************************************\
 * -removeButtonPressed:
 *
 * Handle clicks on the '-' (remove) button - remove selected rows from the
 * folder view.
 *
 * In:       ( id ) sender
 *           Sender (may be nil).
 *
 * See also: -folderListSelectionChanged:
\******************************************************************************/

- ( IBAction ) removeButtonPressed: ( id ) sender
{
    /* Without doing deselectAll, row indices that were selected before we
     * removed data stay selected after. Visually, it doesn't seem to make
     * any difference if we take a copy of the selected row indices, then
     * deselect all, then remove items; or if we just remove the items, then
     * deselect everything. Since the latter uses less memory and is quicker,
     * that's the path chosen here.
     */

    [ tableContents removeObjectsAtIndexes: [ folderList selectedRowIndexes ] ];
    [ folderList    deselectAll: self ];
    [ folderList    reloadData        ];
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Implement NSTableViewDataSource
//------------------------------------------------------------------------------

/******************************************************************************\
 * -numberOfRowsInTableView:tableView
 *
 * NSTableViewDataSource: Return the number of rows of data to show in the
 * table view. Side effect: Enables or disables the 'start' button according
 * to whether or not (respectively) there are any rows in the view.
 *
 * In:  ( NSTableView * ) tableView
 *      View making the request.
 *
 * Out: ( NSInteger )
 *      Number of rows of data currently available.
\******************************************************************************/

- ( NSInteger ) numberOfRowsInTableView: ( NSTableView * ) tableView
{
    BOOL enabled = ( [ tableContents count ] != 0 );

    [ startButton setEnabled: enabled ];
    [ clearButton setEnabled: enabled ];

    return [ tableContents count ];
}

/******************************************************************************\
 * -tableView:objectValueForTableColumn:row:
 *
 * NSTableViewDataSource: Return an item of data to show in the given table,
 * table row and table column.
 *
 * In:  ( NSTableView * ) tableView
 *      View making the request;
 *
 *      ( NSTableColumn * ) tableColumn
 *      Column identifier (identifier property values 'path' and 'style' are
 *      expected);
 *
 *      ( NSInteger ) row
 *      Row index (from zero upwards).
 *
 * Out: ( id )
 *      Data to display - an autoreleased NSString pointer cast to 'id'.
\******************************************************************************/

- ( id )                 tableView: ( NSTableView   * ) tableView
         objectValueForTableColumn: ( NSTableColumn * ) tableColumn
                               row: ( NSInteger       ) row
{
    NSDictionary * record = tableContents[row];
    id             value  = record[ [ tableColumn identifier ] ];

    if ( tableColumn == folderListStyleColumn )
    {
        value = [ ( ( IconStyle * ) value ) name ];
    }

    return value;
}

/******************************************************************************\
 * -tableView:writeRowsWithIndexes:toPasteboard:
 *
 * NSTableViewDataSource: Handle starting a drag by recording the dragged row
 * indices on the given pasteboard. Selected rows are moved when dropped.
 *
 * In:  ( NSTableView * ) tableView
 *      View making the request;
 *
 *      ( NSIndexSet * ) rowIndexes
 *      Rows being dragged;
 *
 *      ( NSPasteboard * ) pboard
 *      Pasteboard to which row index data should be saved.
 *
 * Out: ( BOOL )
 *      YES if successful else NO.
\******************************************************************************/

- ( BOOL )            tableView: ( NSTableView  * ) tableView
           writeRowsWithIndexes: ( NSIndexSet   * ) rowIndexes
                   toPasteboard: ( NSPasteboard * ) pboard
{
    [ pboard declareTypes: @[ NSINDEXSET_ON_PBOARD ]
                    owner: nil ];

    return [ pboard setData: [ NSKeyedArchiver archivedDataWithRootObject: rowIndexes ]
                    forType: NSINDEXSET_ON_PBOARD ];
}

/******************************************************************************\
 * -tableView:validateDrop:proposedRow:proposedDropOperation:
 *
 * NSTableViewDataSource: Validate a proposed drop operation.
 *
 * In:  ( NSTableView * ) tableView
 *      View making the request;
 *
 *      ( id < NSDraggingInfo > ) info
 *      Information on the nature of this drag operation;
 *
 *      ( NSInteger ) row
 *      Target drop point row.
 *
 *      ( NSTableViewDropOperation ) operation
 *      The proposed drop operation (e.g. drop-on, drop-above).
 *
 * Out: ( NSDragOperation )
 *      A drag operation - e.g. NSDragOperationMove for row drags or
 *      NSDragOperationNone if the drag is not supported.
\******************************************************************************/

- ( NSDragOperation ) tableView: ( NSTableView            * ) tableView
                   validateDrop: ( id < NSDraggingInfo >    ) info
                    proposedRow: ( NSInteger                ) row
          proposedDropOperation: ( NSTableViewDropOperation ) operation
{
    [ tableView setDropRow: row dropOperation: NSTableViewDropAbove ];

    /* Reordering rows within the file list or dragging from elsewhere? */

    if ( [ info draggingSource ] == folderList )
    {
        return NSDragOperationMove;
    }
    else
    {
        /* Don't allow this unless every dragged on item is a folder */

        NSFileManager * fileManager = [ NSFileManager defaultManager ];
        NSPasteboard  * pboard      = [ info draggingPasteboard ];
        NSArray       * pathnames   = [ pboard propertyListForType: NSFilenamesPboardType ];
        BOOL            acceptable  = YES;

        for ( NSString * path in pathnames )
        {
            BOOL exists, isDirectory;

            exists = [ fileManager fileExistsAtPath: path isDirectory: &isDirectory ];

            if ( exists == NO || isDirectory == NO )
            {
                acceptable = NO;
                break;
            }
        }

        return ( acceptable == YES ) ? NSDragOperationCopy : NSDragOperationNone;
    }
}

/******************************************************************************\
 * -tableView:acceptDrop:row:dropOperation:
 *
 * NSTableViewDataSource: Accept and act upon a drop operation.
 *
 * In:  ( NSTableView * ) tableView
 *      View making the request;
 *
 *      ( id < NSDraggingInfo > ) info
 *      Information on the nature of this drag operation;
 *
 *      ( NSInteger ) row
 *      Target drop point row.
 *
 *      ( NSTableViewDropOperation ) operation
 *      The drop operation (e.g. drop-on, drop-above).
 *
 * Out: ( BOOL )
 *      YES if successful else NO.
\******************************************************************************/

- ( BOOL ) tableView: ( NSTableView            * ) tableView
          acceptDrop: ( id < NSDraggingInfo >    ) info
                 row: ( NSInteger                ) row
       dropOperation: ( NSTableViewDropOperation ) operation
{
    BOOL           added  = NO;
    NSPasteboard * pboard = [ info draggingPasteboard ];

    [ folderList deselectAll: self ];
    
    /* Reordering rows within the file list or dragging from elsewhere? */

    if ( [ info draggingSource ] == folderList )
    {
        /* Reorder rows */

        NSData     * archivedNSIndexSet = [ pboard dataForType: NSINDEXSET_ON_PBOARD ];
        NSIndexSet * draggedRows        = [ NSKeyedUnarchiver unarchiveObjectWithData: archivedNSIndexSet ];

        /* We have to:
         *
         * - Extract the dragged rows into a new temporary array;
         * - Remove the dragged rows;
         * - Correct the target row number to account for removal if necessary;
         * - Insert the temporary array as a contiguous block at the target row;
         * - Tell the table about the change;
         * - Select the moved rows.
         */

        if ( row < 0 /* -1 => end-of-table */ ) row = [ tableContents count ];

        NSArray * movedItems = [ tableContents objectsAtIndexes: draggedRows ];
        [ tableContents removeObjectsAtIndexes: draggedRows ];

        if ( row > 0 )
        {
            NSUInteger above = [ draggedRows countOfIndexesInRange: NSMakeRange( 0, row ) ];
            row -= above;
        }

        NSIndexSet * insertAt = [ NSIndexSet indexSetWithIndexesInRange: NSMakeRange( row, [ movedItems count] ) ];
        [ tableContents insertObjects: movedItems atIndexes: insertAt ];

        [ folderList reloadData ];
        [ folderList selectRowIndexes: insertAt byExtendingSelection: NO ];

        added = YES;
    }
    else
    {
        /* Add list of dragged-on file(names). First, bounds check the
         * addition row.
         */

        NSUInteger itemCount = [ tableContents count ];
        if ( row < 0 /* -1 => end-of-table */ || row > itemCount ) row = itemCount;

        /* Get the list of pathnames and add them at successively higher rows.
         * At the end, 'currentRow' will point to just after the inserted rows.
         */
    
        NSArray * pathnames = [
                                 [ pboard propertyListForType: NSFilenamesPboardType ]
                                 sortedArrayUsingSelector: @selector( localizedCaseInsensitiveCompare: )
                              ];

        NSUInteger currentRow = row;

        for ( NSString * path in pathnames )
        {
            [ self insertFolder: path atIndex: currentRow ];
            currentRow ++;
            added = YES;
        }

        /* Build ranges for the array start to just before the insertion row;
         * for the inserted rows; and for just after the inserted rows to the
         * end of the array. Then amalgamate the first and last of those so
         * we have an array of indices of 'old' and 'new' items.
         */

        NSMutableIndexSet * beforeAddition = [ NSMutableIndexSet indexSetWithIndexesInRange: NSMakeRange( 0, row ) ];
        NSIndexSet        * duringAddition = [ NSIndexSet        indexSetWithIndexesInRange: NSMakeRange( row, currentRow - row ) ];
        NSIndexSet        * afterAddition  = [ NSIndexSet        indexSetWithIndexesInRange: NSMakeRange( currentRow, [ tableContents count ] - currentRow ) ];

        [ beforeAddition addIndexes: afterAddition ];

        /* Use these results to call the duplicates removal routine */

        NSIndexSet * deleted = [ self removeDuplicatesFromIndices: beforeAddition
                                                  comparedAgainst: duringAddition ];
        
        /* If sub-folders are to be added, they'd start being added at an index
         * of 'currentRow' but deletions above may have invalidated that. We
         * need to find out how many items 'above' this row were removed and
         * decrement the index by that value. In fact we can be a bit more
         * clever since we know we only deleted items from the 'beforeAddition'
         * index set and the only indices possibly 'above' currentRow in this
         * would be between 0 and 'row' (see definition of 'beforeAddition'
         * above), so only look at that range.
         */

        currentRow -= [ deleted countOfIndexesInRange: NSMakeRange( 0, row ) ];

        /* Tell the folder list table view about the changes and look into
         * possible addition of sub-folders at the possibly adjusted index.
         */

        [ folderList reloadData ];

        [
            self considerInsertingSubfoldersOf:
            @{
              @"strings":    pathnames,
              @"firstIndex": @( currentRow )
            }
        ];

        /* Whatever happens, select the parents. In practice, this is a nice
         * thing to do when children are added below as often you want to add
         * icons to a bunch of sub-folders, but not the parents; it's easiest
         * to turn on 'Add sub-folders', then drag on the parents, then just
         * delete the parents once sub-folder addition is complete.
         */

        NSIndexSet * newItems = [ NSIndexSet indexSetWithIndexesInRange: NSMakeRange( row, currentRow - row ) ];
        [ folderList selectRowIndexes: newItems byExtendingSelection: NO ];
    }

    return added;
}

//------------------------------------------------------------------------------
#pragma mark -
#pragma mark Style submenu and style management
//------------------------------------------------------------------------------

/******************************************************************************\
 * -menuNeedsUpdate:
 *
 * NSMenuDelegate: A submenu is about to open. Only the Styles submenu is
 * handled by this method.
 *
 * In: ( NSMenu * ) menu
 *     Must be "stylesSubMenu", else the method will do nothing.
\******************************************************************************/

- ( void ) menuNeedsUpdate: ( NSMenu * ) menu
{
    if ( menu != stylesSubMenu ) return;

    /* Just rebuild the whole menu - it's small and doesn't take long */

    [ stylesSubMenu removeAllItems ];

    /* Item sort order is configured by IconStyleArrayController */

    for ( IconStyle * obj in [ stylesArrayController arrangedObjects ] )
    {
        NSMenuItem * item = [ stylesSubMenu addItemWithTitle: [ obj name ]
                                                      action: @selector( styleSubmenuItemChosen: )
                                               keyEquivalent: @"" ];

        [ item setRepresentedObject: obj ];
    }
}

/******************************************************************************\
 * -styleSubmenuItemChosen:
 *
 * An item in the Styles submenu has been chosen. At least one row should be
 * selected in the folder list so that its style can be changed. If none are
 * selected for some reason, or if the menu item appears to not represent an
 * icon style, this method will do nothing.
 *
 * In:       ( NSMenuItem * ) sender
 *           The selected menu item.
 *
 * See also: -menuNeedsUpdate:
\******************************************************************************/

- ( IBAction ) styleSubmenuItemChosen: ( NSMenuItem * ) sender
{
    IconStyle * iconStyle = [ sender representedObject ];
    if ( iconStyle == nil || [ folderList numberOfSelectedRows ] == 0 ) return;

    NSIndexSet * selectedIndices = [ folderList selectedRowIndexes ];

    [
        selectedIndices enumerateIndexesUsingBlock:
        ^ ( NSUInteger index, BOOL * stop )
        {
            NSMutableDictionary * record = tableContents[ index ];
            [ record setValue: iconStyle forKey: @"style" ];
        }
    ];

    [ folderList reloadData ];
}

/******************************************************************************\
 * -iconStyleListChanged:
 *
 * Called from the default NSNotificationCenter when the IconStyle collection
 * managed by CoreData changes.
 *
 * The method checks to see if all the styles used in the current list of
 * folders are defined. If any are deleted, a default style is used instead.
 *
 * In: ( NSNotification * ) notification
 *     The notification details.
\******************************************************************************/

- ( void ) iconStyleListChanged: ( NSNotification * ) notification
{
    NSDictionary * userInfo      = [ notification userInfo ];
    NSSet        * deletedStyles = userInfo[ NSDeletedObjectsKey ];

    if ( [ deletedStyles count ] == 0 ) return;

    /* For each entry in the folder list, see if it uses a deleted style. If
     * it does, change that style. We can at least get Grand Central to help
     * out with this via NSArray's concurrent block-based enumeration.
     *
     * The default style code copes with in-progress deletions of the
     * configured default style so we can rely on it to return a valid style.
     */

    IconStyle * defaultStyle = [ iconStyleManager findDefaultIconStyle ];

    [
        tableContents enumerateObjectsWithOptions: NSEnumerationConcurrent
                                       usingBlock: ^ ( NSDictionary * item, NSUInteger index, BOOL * stop )
        {
            ( void ) index;
            ( void ) stop;
        
            IconStyle * usedStyle = item[ @"style" ];

            if ( [ deletedStyles containsObject: usedStyle ] )
            {
                [ item setValue: defaultStyle forKey: @"style" ];
            }
        }
    ];

    [ folderList reloadData ];
}

@end
