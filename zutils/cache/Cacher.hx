package megamod.cache;

import funkin.backend.system.Logs;
import funkin.backend.utils.NativeAPI.ConsoleColor;
import funkin.backend.utils.ThreadUtil;
import funkin.backend.assets.ModsFolder;
import animate.FlxAnimateFrames;
import flixel.graphics.FlxGraphic;
import openfl.media.Sound;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import lime.app.Promise;
import lime.app.Future;
import sys.thread.Mutex;
import sys.FileSystem;



/**
 * The asset cacher caches assets inside of the manifest.
 * This leverages openfl's asset caching, in combination
 * with flixel's graphic caching, so any cached
 * assets will stay in memory until openfl's/fixel's cache
 * is cleared.
 * 
 * #### The Cacher will be effective in cases where you're loading sounds or images with flixel.
 * 
 * ---
 * 
 * ## How to use
 * 
 * You can use the Cacher as such:
 * ```
 * var cacher = new Cacher();
 * cacher.setManifestEntry('background', { assetPath: 'background.png', assetType: AssetType.IMAGE(false) });
 * cacher.setManifestEntry('music', { assetPath: 'music.mp3', assetType: AssetType.AUDIO });
 * cacher.startCacher();
 * ```
 * 
 * 
 * It also allows you to pass in a manifest directly:
 * ```
 * var cacher = new Cacher([
 *     'background' => { assetPath: 'background.png', assetType: AssetType.IMAGE(false) },
 *     'music' => { assetPath: 'music.mp3', assetType: AssetType.AUDIO }
 * ]);
 * cacher.startCacher();
 * ```
 * 
 * And if you want, you can also cache many assets asynchronously:
 * ```
 * var cacher = new Cacher();
 * cacher.setManifestEntry('background', { assetPath: 'background.png', assetType: AssetType.IMAGE(false) });
 * cacher.setManifestEntry('music', { assetPath: 'music.mp3', assetType: AssetType.AUDIO });
 * cacher.startCacherAsync().onComplete((res) -> trace(res)).onError((res) -> trace(res));
 * ```
 * 
 * ---
 * 
 * ### Immediate mode
 * 
 * You can also use immediate mode. This means that you can
 * cache singular assets quickly on the fly, without
 * loading them up and caching them in one go.
 * 
 * You can use it as such:
 * ```
 * var cacher = new Cacher(null, true);
 * cacher.allocateEntry({ assetPath: 'background.png', assetType: AssetType.IMAGE(false) });
 * cacher.allocateEntry({ assetPath: 'music.mp3', assetType: AssetType.AUDIO });
 * ```
 * 
 * @see `Cacher.immediateMode`
 */
class Cacher {
    /**
     * Whether or not this Cacher prints verbose prints.
     * Even if this is true, this will only work if Codename engine is launched with the --verbose flag.
     */
    public var verbose = false;

    /**
     * The manifest belonging to this Cacher.
     */
    private var manifest:Manifest = [];

    /**
     * Returns the manifest belonging to this Cacher.
     * @return `Manifest` - The manifest belonging to this Cacher.
     */
    public function getManifest():Manifest
        return manifest;

    /**
     * Sets the manifest belonging to this Cacher.
     * @param manifest - The manifest to set.
     */
    public function setManifest(manifest:Manifest) {
        this.manifest = manifest;
    }

    
    /**
     * Whether or not this Cacher is in immediate mode.
     * Immediate mode means that you can allocate/cache
     * assets on the fly instead of loading them up
     * and caching them in one go.
     * 
     * This can be useful in cases where you're
     * making a loading screen and need to load assets
     * progressively to avoid blocking the thread,
     * or maybe you just need to cache one thing quickly.
     * 
     * You can use it as such:
     * ```
     * var cacher = new Cacher(null, true);
     * var success = cacher.allocateEntry({assetPath: 'test.png', assetType: AssetType.IMAGE(false)});
     * if (success) {
     *     // do something
     * } else {
     *     trace('Failed to allocate entry!');
     * }
     * ```
     * 
     * @see `Cacher.allocateEntry`
     */
    private var immediateMode:Bool = false;

    /**
     * Gets whether or not this Cacher is in immediate mode.
     * @return Bool - Whether or not this Cacher is in immediate mode.
     */
    public function getImmediateMode():Bool
        return immediateMode;

    /**
     * Sets whether or not this Cacher is in immediate mode.
     * @param immediateMode - Whether or not this Cacher is in immediate mode.
     */
    public function setImmediateMode(immediateMode:Bool) {
        this.immediateMode = immediateMode;
    }

    /**
     * The mutex for this Cacher.
     * Used for thread safety during asynchronous caching
     * outside of immediate mode.
     * 
     * @see `Cacher.startCacherAsync`
     */
    private var mutex:Mutex = new Mutex();

    /**
     * Initializes this Cacher.
     * @param manifest - The manifest to cache. Can be null.
     */
    public function new(?manifest:Manifest, ?immediateMode:Bool = false) {
        if (manifest != null) this.manifest = manifest;
        this.immediateMode = immediateMode;
    }

    /**
     * Sets an entry in the manifest.
     * Only available outside of immediate mode.
     * @param entry - The entry to set.
     */
    public function setManifestEntry(id:String, entry:ManifestEntry) {
        if (immediateMode) {
            Logs.warn('Cannot set entry $id while inside of immediate mode. Did you mean to use "allocateEntry" instead?', ConsoleColor.YELLOW, 'Cacher');
            return;
        }

        for (i in 0...manifest.length) {
            if (manifest[i].id == id) {
                manifest[i] = {id: id, entry: entry};
                return;
            }
        }
        manifest.push({id: id, entry: entry});
    }

    /**
     * Removes an entry from the manifest.
     * Only available outside of immediate mode.
     * 
     * ### This will NOT uncache anything already cached by openfl/flixel!
     * For that, use `Cacher.clearCache` to clear the entire cache.
     * 
     * @see `Cacher.clearCache`
     * @param id - The id of the entry to remove.
     */
    public function removeManifestEntry(id:String) {
        if (immediateMode) {
            Logs.warn('Cannot remove entry "$id" while inside of immediate mode.', ConsoleColor.YELLOW, 'Cacher');
            return;
        }

        var index = -1;
        for (i in 0...manifest.length) {
            if (manifest[i].id == id) {
                index = i;
                break;
            }
        }

        if (index != -1) manifest = []; else {
            Logs.error('Tried to remove entry "$id" which does not exist in the manifest.', ConsoleColor.RED, 'Cacher');
        }
    }

    /**
     * Clears the manifest.
     * Only available outside of immediate mode.
     * 
     * ### This will NOT uncache anything already cached by openfl/flixel!
     * For that, use `Cacher.clearCache` to clear the entire cache.
     * 
     * @see `Cacher.clearCache`
     */
    public function clearManifest() {
        if (immediateMode) {
            Logs.warn('Cannot clear manifest while inside of immediate mode.', ConsoleColor.YELLOW, 'Cacher');
            return;
        }
        manifest.splice(0, manifest.length);
    }

    /**
     * Allocates an entry on the fly.
     * Only available inside of immediate mode.
     * 
     * @param entry - The entry to allocate.
     * @return `Bool` - If it succeeded in allocating the entry.
     */
    public function allocateEntry(entry:ManifestEntry):Bool {
        if (!immediateMode) {
            Logs.warn('Cannot allocate entry while outside of immediate mode. Did you mean to use "setManifestEntry" instead?',ConsoleColor.YELLOW, 'Cacher');
            return false;
        }
        return cache(entry);
    }

    /**
     * Allocates an entry asynchronously on the fly.
     * Only available inside of immediate mode.
     * 
     * Use it as such:
     * ```
     * cacher.allocateEntryAsync({ assetPath: 'background.png', assetType: AssetType.IMAGE(false) })
     *      .onComplete((success) -> trace('Successfully allocated entry!'))
     *      .onError((error) -> trace('Failed to allocate entry!'));
     * ```
     * 
     * @param entry - The entry to allocate.
     * @return `Future<Bool>` - If it succeeded in allocating the entry.
     */
    public function allocateEntryAsync(entry:ManifestEntry):Future<Bool> {
        var promise = new Promise<Bool>();

        if (!immediateMode) {
            Logs.warn('Cannot allocate entry while outside of immediate mode. Did you mean to use "setManifestEntry" instead?',ConsoleColor.YELLOW, 'Cacher');
            promise.error(false);
            return promise.future;
        }

        ThreadUtil.createSafe(() -> {
            var res = cache(entry);
            if (res)
                promise.complete(res);
            else
                promise.error(res);
        });

        return promise.future;
    }

    /**
     * Starts running this Cacher. This is for use after setting
     * entries in the manifest, or after providing a manifest.
     * Only available outside of immediate mode.
     * 
     * @param onProgress - The progress callback. (id, result(1 fail, 0 success), current, total)
     * @see `CacheResult`
     * @return `CacheResult` - The result of the cacher.
     */
    public function startCacher(?onProgress:(String, Int, Int, Int)->Void):Null<CacheResult> {
        var prog = onProgress == null ? (_, _, _, _) -> {} : onProgress;
        return cacheAll(false, prog);
    }

    /**
     * Begins running this Cacher asynchronously.
     * 
     * Use it as such:
     * ```
     * cacher.startCacherAsync().onComplete((res) -> trace(res)).onError((res) -> trace(res));
     * ```
     * 
     * @param onProgress - The progress callback. (id, result(1 fail, 0 success), current, total)
     * @see `CacheResult`
     * @return `Future<Null<CacheResult>>` - The result of the cacher.
     */
    public function startCacherAsync(?onProgress:(String, Int, Int, Int)->Void):Future<Null<CacheResult>> {
        var promise:Promise<Null<CacheResult>> = new Promise<Null<CacheResult>>();
        var prog = onProgress == null ? (_, _, _, _) -> {} : onProgress;
        ThreadUtil.createSafe(() -> {
            var res = null;
            res = cacheAll(true, prog);
            if (res == null) {
                promise.error(null);
                return;
            }
            promise.complete(res);
        });

        return promise.future;
    }

    /**
     * The internal call which caches all assets.
     * Only available outside of immediate mode.
     * 
     * The async parameter only includes thread safety, not actually
     * running this operation asynchronously.
     * 
     * @see `CacheResult`
     * @see `Cacher.startCacher`
     * @see `Cacher.startCacherAsync`
     * 
     * @param async - Whether or not to set up for asynchronous caching.
     * @return `Null<CacheResult>` - The result of the cacher.
     */
    private function cacheAll(async:Bool = false, onProgress:(String, Int, Int, Int)->Void):Null<CacheResult> {
        var res:CacheResult = {
            successes: [],
            failures: []
        };

        if (immediateMode) {
            Logs.warn('Cannot start cacher while inside of immediate mode. Did you mean to use a series of "allocateEntry" calls instead?', ConsoleColor.YELLOW, 'Cacher');
            return null;
        }
        var numSuccesses = 0;
        var numFailures = 0;

        var manifest:Manifest = [];

        if (async) {
            mutex.acquire();
            for (item in this.manifest) {
                manifest.push({
                    id: item.id,
                    entry: {
                        assetPath: item.entry.assetPath,
                        assetType: item.entry.assetType
                    }
                });
            }
            mutex.release();
        } else
            manifest = this.manifest;

        for (item in manifest) {
            var id = item.id;
            var entry = item.entry;
            var result = cache(entry);
            if (result) {
                numSuccesses++;
                onProgress(id, 0, numSuccesses + numFailures, manifest.length);
                res.successes.push(entry);
                if (verbose)
                    Logs.verbose('Successfully cached "$id"', ConsoleColor.LIGHTGRAY, 'Cacher');
            } else {
                numFailures++;
                onProgress(id, 1, numSuccesses + numFailures, manifest.length);
                res.failures.push(entry);
                if (verbose)
                    Logs.warn('Failed to cache "$id"', ConsoleColor.YELLOW, 'Cacher');
            }
        }
        if (verbose)
            Logs.infos('Successfully cached $numSuccesses/${numSuccesses + numFailures} assets.', ConsoleColor.LIGHTGRAY, 'Cacher');
        
        return res;
    }

    /**
     * The internal cache function.
     * @param entry - The entry to cache.
     * @return `Bool` - If it succeeded in caching the entry.
     */
    private function cache(entry:ManifestEntry):Bool {
        var res = false;

        // This code disgusts me. No I'm not going to rewrite it.
        var finalPath = entry.assetPath;
        if (!FileSystem.exists(finalPath)) {
            finalPath = ModsFolder.modsPath + ModsFolder.currentModFolder + '/' + entry.assetPath.substr(7);
            if (!FileSystem.exists(finalPath)) {
                if (!FileSystem.exists('./' + entry.assetPath)) {
                    if (FileSystem.exists('./' + Paths.image(entry.assetPath))) {
                        Logs.warn('Asset "$finalPath", "./${entry.assetPath}", or "./${Paths.image(entry.assetPath)}" does not exist.', ConsoleColor.YELLOW, 'Cacher');
                        return res;
                    } else
                        finalPath = './' + Paths.image(entry.assetPath);
                } else
                    finalPath = './' + entry.assetPath;
            }
        }

        switch (entry.assetType) {
            case AssetType.IMAGE(unique):
                // For flixel
                var bitmap = BitmapData.fromFile(finalPath);
                var graphic:FlxGraphic = FlxG.bitmap.add(bitmap, unique);
                if (graphic == null) {
                    Logs.error('Failed to cache image "${finalPath}".', ConsoleColor.RED, 'Cacher');
                    return res;
                }
                var spr:FunkinSprite = new FunkinSprite(0, 0, entry.assetPath);
                spr.destroy();
                res = true;
            case AssetType.AUDIO:
                var sound = new FlxSound();
                sound.loadEmbedded(Sound.fromFile(finalPath));
                sound.destroy();
                res = true;
        }

        return res;
    }

    /**
     * Clears the global cache completely inside of flixel and openfl.
     * Graphics object will be removed and destroyed only if it shouldn't persist in the cache and its useCount is 0.
     */
    public static function clearCache() {
        FlxG.bitmap.clearCache();
        Assets.cache.clear();
    }
}
