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

-   (void) getSetting:(CDVInvokedUrlCommand *)command;
-   (void) setSetting:(CDVInvokedUrlCommand *)command;
-	(NSString*) getSettingFromBundle:(NSString*)settingName;


@end
