//
//  SlipCoverSupport.h
//  Add Folder Icons
//
//  Created by Andrew Hodgkinson on 06/02/2011.
//  Copyright 2011 Hipposoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CaseDefinition.h"

@interface SlipCoverSupport : NSObject
{
}

+ ( NSString       * ) slipCoverApplicationPath;
+ ( NSMutableArray * ) searchPathsForCovers;
+ ( void             ) enumerateSlipCoverDefinitionsInto: ( NSMutableArray * ) slipCoverDefinitions
                                                thenCall: ( id               ) instance
                                                    with: ( SEL              ) selector;

+ ( CaseDefinition * ) findDefinitionFromName: ( NSString * ) name
                            withinDefinitions: ( NSArray  * ) caseDefinitions;

@end
