package zutils.native.lib;

/**
 * The data of an entry in an NDLL.
 * 
 * @see `Native`
 */
typedef NDLLEntry = {
    /**
     * The name of the function.
     */
    var funcName:String;
    
    /**
     * The number of arguments the function takes.
     */
    var numArgs:Int;
};