/*
 *  FolderProcessNotificationProtocol.h
 *  Add Folder Icons
 *
 *  Created by Andrew Hodgkinson on 05/02/2011.
 *  Copyright 2011 Hipposoft. All rights reserved.
 *
 */

/* On the application side, the MainWindowController sets itself up as a root
 * object for a connection with the name below and implements the
 * 'FolderProcessNotification' protocol. The CLI tool is supposed to connect
 * and make calls to the single implemented method. Here, it provides the most
 * recently successfully processed folder. The return value tells it whether
 * (YES) or not (NO) it should cancel its processing and exit.
 */

#define APP_SERVER_CONNECTION_NAME @"uk.org.pond.Add-Folder-Icons" /* If this changes, be sure to update the corresponding temporary Mach service entitlement in "Add Folder Icons.entitlements" */

@protocol FolderProcessNotification

- ( BOOL ) folderProcessedSuccessfully: ( NSString * ) fullPOSIXPath;

@end
