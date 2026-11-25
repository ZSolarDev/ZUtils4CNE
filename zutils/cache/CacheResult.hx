package megamod.cache;

/**
 * The result of a full cache operation.
 * 
 * @see `Cacher`
 */
typedef CacheResult = {
    var successes:Array<ManifestEntry>;
    var failures:Array<ManifestEntry>;
}