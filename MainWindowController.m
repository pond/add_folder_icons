//
//  MainWindowController.m
//
//  Created by Andrew Hodgkinson on 28/03/2010.
//  Copyright 2010, 2011 Hipposoft. All rights reserved.
//

#import "MainWindowController.h"
#import "ApplicationSupport.h"

#import "Icons.h"
#import "CustomIconGenerator.h"
#import "SlipCoverSupport.h"
#import "GlobalConstants.h"
#import "GlobalSemaphore.h"
#import "ConcurrentCellProcessor.h"
#import "ConcurrentPathProcessor.h"

#import <Foundation/Foundation.h>

#define NSINDEXSET_ON_PBOARD @"NSIndexSetOnPboardType"

@interface MainWindowController()
@property NSOperationQueue * queue;
@end

@implementation MainWindowController

@synthesize iconStyleManager,
            managedObjectContext,
            managedObjectModel;

- ( void ) awakeFromNib
{
    tableContents = [ [ NSMutableArray   alloc ] init ];
    self.queue    = [ [ NSOperationQueue alloc ] init ];

    /* Although documentation implies that the system should be left alone to
     * set this up, in practice doing so causes very high system workload for
     * large numbers of folders. Trying to cancel the operation takes a long
     * time, because OS X appears to queue *all* operations extremely quickly,
     * then has to cancel the whole lot.
     *
     * By restricting concurrency, this up-front queueing and latency comes
     * under control. OS X may choose to use *less* than this of course, it's
     * just a maximum. The value chosen here should soak CPUs on most machines
     * but still (at least on the author's laptop at the time of writing)
     * responds to cancellation quickly.
     *
     * This is entirely unscientific and unsatisfactory but given OS X's poor
     * behaviour here (was OK on 10.6, got bad in 10.7, still bad in 10.10.2)
     * there doesn't seem to be another way; though if anyone else other than
     * me ever reads this and has suggestions, I'd love to hear them!
     */

    self.queue.maxConcurrentOperationCount = 8;
    
    [ self initOpenPanel      ];
    [ self initWindowContents ];

    /* On OS X Yosemite (10.10.x) and later, the green 'zoom' window control
     * changes to become 'full screen'. This is nonsensical for an application
     * that really needs to live alongside Finder windows to be useful, even
     * given split screen in OS X El Capitan (10.11.x).
     *
     * Setting the button behaviour to 'auxiliary' in the XIB file causes
     * warnings about compatibility before OS X 10.7; we'd quite like to stay
     * compatible with OS X 10.6 if possible. So instead, set this at run time
     * if on OS X 10.10 or later.
     *
     * It just so happens that a high level interface to determine OS X version
     * was introduced in 10.10 - so if this exists, we already know we're on a
     * new enough version.
     */

    if ( [ [ NSProcessInfo processInfo ] respondsToSelector: @selector( operatingSystemVersion ) ] )
    {
        self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenAuxiliary;
    }
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

- ( instancetype ) initWithWindowNibName: ( NSString * ) windowNibName
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

    [ folderListClipView setPostsBoundsChangedNotifications: YES ];

    [ [ NSNotificationCenter defaultCenter ] addObserver: self
                                                selector: @selector( scrollPositionChanged: )
                                                    name: NSViewBoundsDidChangeNotification
                                                  object: folderListClipView ];

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
    globalErrorFlag = NO;

    for ( NSDictionary * folder in constArrayOfDictionaries )
    {
        NSString  * fullPOSIXPath = folder[ @"path"  ];
        IconStyle * iconStyle     = folder[ @"style" ];

        ConcurrentPathProcessor * processThisPath =
        [
            [ ConcurrentPathProcessor alloc ] initWithIconStyle: iconStyle
                                                   forPOSIXPath: fullPOSIXPath
        ];

        /* Set a completion block that runs whether the operation is successful,
         * fails or is cancelled. In the event we can see that the worker thread
         * is cancelled (via the modal progress panel's "Stop" button, tell the
         * queue to cancel everything. Even though we'll repeat this over and
         * over for all remaining in-flight operations on the queue, it's
         * harmless to do so and keeps the code simple.
         */

        [
            processThisPath setCompletionBlock: ^
            {
                if ( [ self->workerThread isCancelled ]  == YES )
                {
                    [ self.queue cancelAllOperations ];
                }
                else
                {
                    [ self performSelectorOnMainThread: @selector( advanceProgressBarFor: )
                                            withObject: fullPOSIXPath
                                         waitUntilDone: NO ];
                }
            }
        ];

        /* Outside the completion block, here in the loop adding operations, we
         * also need to check for thread cancellation and use that to cancel the
         * queue operations before bailing out of the addition loop.
         */

        if ( [ workerThread isCancelled ] == YES )
        {
            [ self.queue cancelAllOperations ];
            break;
        }
        else
        {
            [ self.queue addOperation: processThisPath ];
        }
    }

    [ self.queue waitUntilAllOperationsAreFinished ];

    /* If things went wrong tell the user in a modal alert opened from within
     * this modal loop, so the progress panel is still visible as an indication
     * of continuity between the addition process and the alert.
     *
     * The ConcurrentPathProcessor code sets (thread-safely) a global error flag
     * to let us know when something went wrong, albeit in a rather crude way.
     *
     * If things went *right*, ask the main thread to consider removing folders
     * from the folder list (depending on preferences it may or may not do so).
     */

    if ( globalErrorFlag )
    {
        [ self performSelectorOnMainThread: @selector( showAdditionFailureAlert )
                                withObject: nil
                             waitUntilDone: YES ];
    }
    else if ( [ [ NSThread currentThread ] isCancelled ] == NO )
    {
        [ self performSelectorOnMainThread: @selector( considerEmptyingFolderList )
                                withObject: nil
                             waitUntilDone: YES ];
    }

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
 * In: ( NSString * ) fullPOSIXPath
 *     Full POSIX path of the folder which was successfully processed.
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
    NSString * title   = NSLocalizedString( @"Icon Addition Failure", @"Title of alert reporting a failure to add all icons" );
    NSString * message = NSLocalizedString( @"One or more of the folder addition attempts failed. You could try again with the existing folder list, clear the folder list and try with a new set of folders, or add fewer folders at a time.", @"Message shown in alert reporting a failure to add all icons ");
    NSString * button  = NSLocalizedString( @"Continue", @"Button shown in alert reporting a failure to add all icons" );
    NSAlert  * alert   = [ [ NSAlert alloc ] init ];

    alert.alertStyle      = NSCriticalAlertStyle;
    alert.messageText     = title;
    alert.informativeText = message;

    [ alert addButtonWithTitle: button ];
    [ alert runModal                   ];
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
            NSDictionary * matchRecord = self->tableContents[ matchIndex ];
            NSString     * matchPath   = [ matchRecord valueForKey: @"path" ];

            NSUInteger found =
            [
             self->tableContents indexOfObjectWithOptions: NSEnumerationConcurrent
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
 * -scrollPositionChanged:
 *
 * Called via the default NSNotificationCenter when notification message is
 * "NSViewBoundsDidChangeNotification" sent by the folder list, implying a
 * scroll event. Kicks the table to make sure that lazy generation of preview
 * icons is carried out on all OS versions.
 *
 * In:       ( NSNotification * ) notification
 *           The notification details (ignored).
 *
 * See also: -tableView:objectValueForTableColumn:row:
\******************************************************************************/

- ( void ) scrollPositionChanged: ( NSNotification * ) notification
{
    ( void ) notification;

    [ NSObject cancelPreviousPerformRequestsWithTarget: folderList selector: @selector( reloadData ) object: nil ];
    [ folderList performSelector: @selector( reloadData ) withObject: nil afterDelay: 0.1 ];
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

            NSUInteger originalCount = self->tableContents.count;
            NSUInteger additionCount = self->openPanel.URLs.count;

            for ( NSURL * url in self->openPanel.URLs )
            {
                NSString * pathBeingAdded = url.path;
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

            [ self->folderList reloadData ];
            [ self considerInsertingSubfoldersOf: @{ @"urls": self->openPanel.URLs } ];
        }
	};

    [ openPanel beginSheetModalForWindow: self.window
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
    BOOL enabled = ( tableContents.count != 0 );

    startButton.enabled = enabled;
    clearButton.enabled = enabled;

    return tableContents.count;
}

/******************************************************************************\
 * -tableView:objectValueForTableColumn:row:
 *
 * NSTableViewDataSource: Return an item of data to show in the given table,
 * table row and table column. In some versions of OS X this is called whenever
 * the user scrolls the table. In other versions, the whole table is populated
 * up-front and only limited calls are subsequently made. Since we want to
 * avoid loading potentially hundreds of images into the table, we only show
 * preview icons for visible rows; but since this method is not reliably then
 * called if the view scrolls, we need to use a notification for scroll events
 * and make sure that the mechanism here is given a little kick. See
 * -scrollPositionChanged: for details.
 *
 * In:  ( NSTableView * ) tableView
 *      View making the request;
 *
 *      ( NSTableColumn * ) tableColumn
 *      Column identifier (identifier property values 'path', 'style' or
 *      'preview' are expected);
 *
 *      ( NSInteger ) row
 *      Row index (from zero upwards).
 *
 * Out: ( id )
 *      Data to display - an autoreleased NSString pointer cast to 'id' or
 *      an NSString.
 *
 * See also: -scrollPositionChanged:
\******************************************************************************/

- ( id )                 tableView: ( NSTableView   * ) tableView
         objectValueForTableColumn: ( NSTableColumn * ) tableColumn
                               row: ( NSInteger       ) row
{
    NSString            * columnId = tableColumn.identifier;
    NSMutableDictionary * record   = tableContents[ row ];
    id                    value    = record[ columnId ];

    if ( [ columnId isEqualToString: @"style" ] )
    {
        value = ( ( IconStyle * ) value ).name;

        if ( [ value hasPrefix: ICON_STYLE_PRESET_PREFIX ] )
        {
            value = [ value substringFromIndex: ICON_STYLE_PRESET_PREFIX.length ];
        }
    }
    else if ( [ columnId isEqualToString: @"preview" ] )
    {
        /* Is there already an operation underway to create a preview image for
         * this row, or an existing image?
         *
         * - There is existing preview data, but it is outdated:
         *
         *   - If there is a cell processor running, cancel it.
         *   - In any event, set record data to 'nil' so ARC can free it all.
         *
         * - There is existing preview data, and it is relevant:
         *
         *   - If there is an existing image, return it.
         *   - If there is a cell processor running, let it continue and return
         *     the default placeholder for now.
         */

        NSImage      * defaultImage     = [ NSImage imageNamed: NSImageNameFolder ];
        IconStyle    * styleForTableRow = record[ @"style"   ];
        NSDictionary * previewData      = record[ @"preview" ];

        if ( previewData )
        {
            if ( previewData[ @"styleID" ] != styleForTableRow.objectID )
            {
                ConcurrentCellProcessor * outdatedProcessor = previewData[ @"cellProcessor" ];
                [ outdatedProcessor cancel ];

                record[ @"preview" ] = nil;
            }
            else
            {
                ConcurrentCellProcessor * runningProcessor = previewData[ @"cellProcessor" ];
                NSImage                 * existingImage    = previewData[ @"previewImage" ];

                if ( existingImage    ) return existingImage;
                if ( runningProcessor ) return defaultImage;
            }
        }

        /* If the row isn't even visible, don't proceed further */

        NSScrollView * scrollView  = [ tableView enclosingScrollView ];
        CGRect         visibleRect = scrollView.contentView.visibleRect;
        NSRange        range       = [ tableView rowsInRect: visibleRect ];

        if ( NSLocationInRange( row, range ) == NO )
        {
            /* If the row isn't visible, even if there's a style-relevant cell
             * processing operation it might as well be cancelled now.
             */

            ConcurrentCellProcessor * runningProcessor = previewData[ @"cellProcessor" ];

            [ runningProcessor cancel ];
            record[ @"preview" ] = nil;

            return defaultImage;
        }

        /* Need to build a preview image */

        ConcurrentCellProcessor * cellProcessor =
        [
            [ ConcurrentCellProcessor alloc ] initForTableView: tableView
                                              andTableContents: tableContents
                                              andRowDictionary: record
        ];

        record[ @"preview" ] =
        @{
            @"styleID":       styleForTableRow.objectID,
            @"cellProcessor": cellProcessor
        };

        [ self.queue addOperation: cellProcessor ];

        /* Meanwhile, return the default folder image */

        value = defaultImage;
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
            NSMutableDictionary * record = self->tableContents[ index ];
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
