# Library Shelf Component

The Library Shelf Component represents one library on the [Home Page](<../pages/home page.md>). It contains the library name followed by a horizontally scrolling row of [Tile Image Components](<tile image component.md>).

The first Tile Image Component opens the full library. It is followed by up to 20 media-item Tile Image Components using the full library's selected filter, sort, and sort order, including the All or Unseen filter and Title, Added At, or Duration sort.

On tvOS, focus moves horizontally between Tile Image Components. The focused media item's [Item Title Component](<item title component.md>) appears below the Library Shelf Component; the Tile Image Component that opens the full library is labeled within the image and does not show a title below the shelf. On non-tvOS platforms, each media item's Item Title Component appears directly below its Tile Image Component.
