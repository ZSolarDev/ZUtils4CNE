package megamod.cache;

/**
 * The manifest of assets. Used to cache assets via the Cacher.
 * 
 * @see `Cacher`
 */
typedef Manifest = Array<{id:String, entry:ManifestEntry}>;