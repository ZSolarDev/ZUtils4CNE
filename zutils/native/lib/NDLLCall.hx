package megamod.native.lib;

/**
 * A call to an NDLL function.
 */
typedef NDLLCall = {
    /**
     * The call.
     */
    var call:Dynamic;
    /**
     * Which NDLL this call belonged to.
     */
    var ndllID:String;
}