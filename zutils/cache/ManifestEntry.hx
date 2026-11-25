package zutils.cache;

/**
 * The manifest entry for an asset.
 * 
 * @see `Manifest`
 */
typedef ManifestEntry = {
    /**
     * The path to the asset.
     */
    var assetPath:String;
    /**
     * The type of asset this is.
     * 
     * @see `AssetType`
     */
    var assetType:AssetType;
}