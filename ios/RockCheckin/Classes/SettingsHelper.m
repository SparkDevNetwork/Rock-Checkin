// <copyright>
// Copyright by the Spark Development Network
//
// Licensed under the Rock Community License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.rockrms.com/license
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// </copyright>
//

#import "SettingsHelper.h"

@implementation SettingsHelper

+ (id)objectForKey: (NSString*) key {

    // Check for settings pushed from MDM
    NSDictionary *serverConfig = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"com.apple.configuration.managed"];
    if(serverConfig == nil) {
        serverConfig = @{};
    }

    if ([serverConfig objectForKey:key] != nil) {
        return [serverConfig objectForKey:key];
    }
    else {
        return [NSUserDefaults.standardUserDefaults objectForKey:key];
    }
}

+ (bool)boolForKey: (NSString*) key {
    NSNumber *result = [SettingsHelper objectForKey:key];
    return [result boolValue];
}

+ (float)floatForKey: (NSString*) key {
    NSNumber *result = [SettingsHelper objectForKey:key];
    return [result floatValue];
}

+ (int)integerForKey: (NSString*) key {
    NSNumber *result = [SettingsHelper objectForKey:key];
    return [result intValue];
}

+ (NSString*)stringForKey: (NSString*) key {
    return [SettingsHelper objectForKey:key];
}

+ (bool)objectIsForcedForKey: (NSString*) key {
    NSDictionary *serverConfig = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"com.apple.configuration.managed"];
    if(serverConfig == nil) {
        serverConfig = @{};
    }
    return ([serverConfig objectForKey:key] != nil || [NSUserDefaults.standardUserDefaults objectIsForcedForKey:key]);
}

@end
