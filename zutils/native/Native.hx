package megamod.native;

import funkin.backend.system.Logs;
import funkin.backend.utils.NativeAPI.ConsoleColor;
import funkin.backend.utils.NdllUtil;
import sys.FileSystem;

/**
 * Native is meant to be extended. It allows simple
 * creation of externs for ndll functions.
 */
class Native {
    /**
     * The bank of ndll funcitons.
     * This is usually used internally by the extender extending this class, but if you
     * need to access the raw functions themselves, `Native` allows you to
     * get specific functions from the `__nativeBank` via `getNCall`/`getNCallIdx`.
     */
    private var __nativeBank:NDLLCallBank = [];

    /**
     * The map of function names to `__nativeBank` indexes.
     * Use it via the `getNCall` function, or `getNCallIdx`.
     */
    private var __ndllMap:NDLLMap = [];

    /**
     * Creates a new `Native` object.
     */
    public function new() {}

    /**
     * Loads an entire ndll into memory.
     * This will replace any funcitons that exist in this ndll and
     * have the same ndll id and function name.
     * @param ndllData - The ndll to load.
     * @return `Bool` - Whether or not the ndll was loaded successfully.
     */
    public function loadNDLL(ndllData:NDLLData):Bool {
        if (!Assets.exists(Paths.ndll('${ndllData.ndllID}-${NdllUtil.os}'))) {
            Logs.error('Failed to load ndll, as it could not be found.', ConsoleColor.RED, 'Native || ${ndllData.ndllID}');
            return false;
        }

        for (entry in ndllData.entries) {
            __nativeBank.push({call: NdllUtil.getFunction(ndllData.ndllID, entry.funcName, entry.numArgs), ndllID: ndllData.ndllID});
            var replaced = false;
            for (pairIdx in 0...__ndllMap.length) {
                var pair = __ndllMap[pairIdx];
                if (pair.name == entry.funcName && pair.ndllID == ndllData.ndllID) {
                    __ndllMap[pairIdx] = {name: entry.funcName, ndllID: ndllData.ndllID, idx: __nativeBank.length - 1};
                    replaced = true;
                    // Don't break, in case more duplicates exist.
                }
            }
            if (!replaced)
                __ndllMap.push({name: entry.funcName, ndllID: ndllData.ndllID, idx: __nativeBank.length - 1});

            Logs.verbose('Successfully loaded function "${entry.funcName}" from ndll "${ndllData.ndllID}".', ConsoleColor.LIGHTGRAY, 'Native || ${ndllData.ndllID}');
        }
        Logs.infos('Successfully loaded ndll "${ndllData.ndllID}".', ConsoleColor.LIGHTGRAY, 'Native || ${ndllData.ndllID}');
    
        return true;
    }

    /**
     * Unloads an entire ndll from memory.
     * @param ndllID - The ID of the ndll to unload.
     * @return `Bool` - Whether or not the ndll was unloaded successfully.
     */
    public function unloadNDLL(ndllID:String):Bool {
        var removedAny = false;
        var toSplice = [];
        for (pairIdx in 0...__ndllMap.length) {
            var pair = __ndllMap[pairIdx];
            if (pair.ndllID == ndllID) {
                // Replace it with a no-op to prevent __ndllMap indexes from being invalidated.
                __nativeBank[pair.idx] = {call: noop(), ndllID: ''};
                toSplice.push(pairIdx);
                removedAny = true;
            }
        }
        // Splice after the loop so all pairIdx's after one splice don't become invalidated.
        for (idx in toSplice)
            __ndllMap.splice(idx, 1);
        if (removedAny)
            Logs.infos('Successfully unloaded ndll "${ndllID}".', ConsoleColor.LIGHTGRAY, 'Native || ${ndllID}');
        else
            Logs.warn('Failed to unload ndll "${ndllID}", as it did not find any registered functions.', ConsoleColor.YELLOW, 'Native || ${ndllID}');
    
        return removedAny;
    }

    /**
     * Gets a native function from `__nativeBank` by name and which ndll it belongs to.
     * @param name - The name of the function.
     * @param ndllID - The ID of the ndll.
     * @return `NDLLCall` - The native function.
     */
    public function getNCall(name:String, ndllID:String):NDLLCall {
        var idx = getNCallIdx(name, ndllID);
        if (idx == -1)
            return {
                call: noop,
                ndllID: '?' 
            };
        return __nativeBank[idx];
    }

    /**
     * Gets the index of a native function from `__nativeBank` by name and which ndll it belongs to.
     * @param name - The name of the function.
     * @param ndllID - The ID of the ndll.
     * @return `Int` - The index of the native function.
     */
    public function getNCallIdx(name:String, ndllID:String):Int {
        for (pair in __ndllMap)
            if (pair.name == name && pair.ndllID == ndllID)
                return pair.idx;
        return -1;
    }

    /**
     * The function does nothing.
     * This is used in case a function is not found with getNCall.
     * I would use NdllUtil.noop, but it's private, and I felt
     * like @:privateAccess wouldn't be needed if I just made this instead.
     */
    static function noop() {}

    /**
     * Calls an NDLL function with no arguments.
     * This is needed because cne-hxcpp gives an Invalid Arg Count
     * error when calling an NDLL function with no arguments.
     * 
     * I still don't know why this fixes it.
     * @param func - The function to call.
     * @return `Dynamic` - The return value of the function, if any.
     */
    public static function callNoArg(func:Dynamic):Dynamic {
        return Reflect.callMethod(null, func, []);
    }
}