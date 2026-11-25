package megamod.cache;

/**
 * The type of asset this is.
 * 
 * @see `ManifestEntry`
 */
enum AssetType {
    /**
     * An image.
     * @param unique - Whether or not the image is unique.
     * Unique images are cached separately.
     */
    IMAGE(unique:Bool);
    AUDIO;
}