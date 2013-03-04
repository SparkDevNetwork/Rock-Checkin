
var ApplicationPreferencesPlugin = {
    
    // get setting
    getApplicationSetting: function (key, success, fail)
    {
        var args = {};
        args.key = key;
        Cordova.exec(success,fail,"ApplicationPreferences","getSetting",[args]);
    },
    
    // get setting
    setApplicationSetting: function (key, value, success, fail)
    {
        var args = {};
        args.key = key;
        args.value = value;
        Cordova.exec(success,fail,"ApplicationPreferences","setSetting",[args]);
    }
    
};