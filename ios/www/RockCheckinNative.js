(function(global) {
    var promises = {};

    /* This can be removed when Rock 1.10.2 is minimum required version. */
    document.addEventListener('DOMContentLoaded', function () {
        console.log('simulating device ready event');
        document.dispatchEvent(new Event('deviceready'));
    }, false);
 
    //
    // Generate a UUID.
    //
    function uuidv4() {
        return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
            (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
        );
    }
    
    global.RockCheckinNative = {
        ResolveNativePromise: function(promiseId, data, error) {
            if (error) {
                promises[promiseId].reject(data);
            }
            else {
                promises[promiseId].resolve(data);
            }

            delete promises[promiseId];
        },
        
        PrintLabels: function(tagJson) {
            return new Promise(function(resolve, reject) {
                var promiseId = uuidv4();
                promises[promiseId] = { resolve, reject };
                
                global.webkit.messageHandlers.RockCheckinNative.postMessage({
                    name: 'PrintLabels',
                    promiseId,
                    data: [tagJson]
                });
            });
        },
        
        StartCamera: function(passive) {
            return new Promise(function(resolve, reject) {
                var promiseId = uuidv4();
                promises[promiseId] = { resolve, reject };
                
                global.webkit.messageHandlers.RockCheckinNative.postMessage({
                    name: 'StartCamera',
                    promiseId,
                    data: [passive]
                });
            });
        },
        
        StopCamera: function() {
            return new Promise(function(resolve, reject) {
                var promiseId = uuidv4();
                promises[promiseId] = { resolve, reject };
                
                global.webkit.messageHandlers.RockCheckinNative.postMessage({
                    name: 'StopCamera',
                    promiseId,
                    data: []
                });
            });
        }
    };
    
    global.Cordova = {
        exec: function(success, fail, className, methodName, data) {
            if (className === 'ZebraPrint' && methodName === 'printTags') {
                global.RockCheckinNative.PrintLabels(data[0])
                    .then(function (result) {
                        success(result);
                    }, function (result) {
                        fail([result.Error, result.canReprint]);
                    });
            }
        }
    }
})(window);

