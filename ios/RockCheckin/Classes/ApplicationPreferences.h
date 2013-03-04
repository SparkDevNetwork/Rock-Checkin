//
//  ApplicationPreferences.h
//  
//
//  Created by Tue Topholm on 31/01/11.
//  Copyright 2011 Sugee. All rights reserved.
//
//  Note: Heavily modified for Cordova 2.4.0 by JME

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>

@interface ApplicationPreferences : CDVPlugin
{

}

-	(void) getSetting:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-	(void) setSetting:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
-	(NSString*) getSettingFromBundle:(NSString*)settingName;


@end
