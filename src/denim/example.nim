import napi/napibindings
# import asyncdispatch, httpclient

proc bro(url: string):string =
    return url
    # return newHttpClient().getContent(url)

init proc(module: Module) =
    # This is how you register a function onto the module.
    # The first argument is the number of arguments you expect
    # And the second one is the name of the function
    # It more or less translates to module.exports.hello = function() ...
    module.registerFn(1, "hello"):
        # All function args can be found in the args array
        # They are stored as napi_values and you need to use
        # conversion methods such as getStr, getInt, getBool, etc. to 
        # get the equivalent Nim value
        var input_url = args[0].getStr
        return %* bro(input_url)

    module.registerFn(0, "world"):
        echo "Hello world"