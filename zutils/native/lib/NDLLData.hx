package megamod.native.lib;

/**
 * The data of an ndll.
 * 
 * @see `Native`
 */
typedef NDLLData = {
    /**
     * The ID of the NDLL under 'ndlls/'.
     * e.g. if the ndll was 'ndlls/Windows/coolNDLL-windows.ndll', this would be 'Windows/coolNDLL'
     */
    var ndllID:String;

    /**
     * The list of functions in the NDLL.
     * This doesn't have to be ALL of them, only the ones with
     * haxe externs that you actually want to use.
     */
    var entries:Array<NDLLEntry>;
};