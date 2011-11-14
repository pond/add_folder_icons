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
+ ( NSMutableArray * ) enumerateSlipCoverDefinitions;
+ ( CaseDefinition * ) findDefinitionFromName: ( NSString * ) name;
+ ( CaseDefinition * ) findDefinitionFromName: ( NSString * ) name
                            withinDefinitions: ( NSArray  * ) caseDefinitions;

@end
