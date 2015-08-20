# Caches
The Libety Buildpack provides a cache abstraction to encapsulate the caching of large files by components.  The cache abstraction is comprised of three cache types each with the same signature.

```ruby
# Retrieves an item from the cache.  Retrieval of the item uses the following algorithm:
#
# 1. Obtain an exclusive lock based on the URI of the item. This allows concurrency for different items, but not for
#    the same item.
# 2. If the the cached item does not exist, download from +uri+ and cache it, its +Etag+, and its +Last-Modified+
#    values if they exist.
# 3. If the cached file does exist, and the original download had an +Etag+ or a +Last-Modified+ value, attempt to
#    download from +uri+ again.  If the result is +304+ (+Not-Modified+), then proceed without changing the cached
#    item.  If it is anything else, overwrite the cached file and its +Etag+ and +Last-Modified+ values if they exist.
# 4. Downgrade the lock to a shared lock as no further mutation of the cache is possible.  This allows concurrency for
#    read access of the item.
# 5. Yield the cached file (opened read-only) to the passed in block. Once the block is complete, the file is closed
#    and the lock is released.
#
# @param [String] uri the uri to download if the item is not already in the cache.  Also used in the case where the
#                     item is already in the cache, to validate that the item is up to date
# @yieldparam [File] file the file representing the cached item. In order to ensure that the file is not changed or
#                    deleted while it is being used, the cached item can only be accessed as part of a block.
# @return [void]
def get(uri)

# Remove an item from the cache
#
# @param [String] uri the URI of the item to remove
# @return [void]
def evict(uri)
```

You can use a cache as follows:

```ruby
LibertyBuildpack::Util::DownloadCache.new().get(uri) do |file|
  YAML.load_file(file)
end
```

## `LibertyBuildpack::Util::DownloadCache`
The [`DownloadCache`][] is the most generic of the three caches.  You can create a cache that persists files anywhere that write access is available.  The constructor signature looks as follows:

```ruby
# Creates an instance of the cache that is backed by the filesystem rooted at +cache_root+
#
# @param [String] cache_root the filesystem directory in which to cache downloaded files
def initialize(cache_root = Pathname.new(Dir.tmpdir))
```

## `LibertyBuildpack::Util::ApplicationCache`
The [`ApplicationCache`][] is a cache that persists files into the application cache passed to the `compile` script.  It examines `ARGV[1]` for the cache location and configures itself accordingly.

```ruby
# Creates an instance that is configured to use the application cache.  The application cache location is defined by
# the second argument (<tt>ARGV[1]</tt>) to the +compile+ script.
#
# @raise if the second argument (<tt>ARGV[1]</tt>) to the +compile+ script is +nil+
def initialize
```

[`ApplicationCache`]: ../lib/liberty_buildpack/util/cache/application_cache.rb
[`DownloadCache`]: ../lib/liberty_buildpack/util/cache/download_cache.rb
