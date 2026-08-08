# Artwork Fallback

## Per-kind behavior

| Kind | Tile shape | Image priority |
|------|-----------|----------------|
| Movie, Series, Season | Portrait (2:3) | Poster → Thumbnail → UI |
| Episode | Landscape (16:9) | Thumbnail → UI (never poster) |
| Other | Landscape (16:9) | Poster → Thumbnail → UI |

## Model layer

`MediaArtworkSet.url(for:)` returns `posterURL ?? landscapeURL` regardless of the style argument. Episodes are protected because the connectors never set `posterURL` for them, so the fallthrough naturally hits `landscapeURL`.

`MediaItemKind.artworkStyle` drives tile shape only:
- `.poster` for movie, series, season
- `.landscape` for episode, other

## Connector mapping

### Plex

| App concept | Plex field | Resolution |
|------------|-----------|-----------|
| Poster | `thumb` | Own `thumb`, else `parentThumb`, else `grandparentThumb` |
| Thumbnail (episodes) | `thumb` | Own `thumb` only |
| Thumbnail (other) | `art` → `thumb` | `art` first, then `thumb` |
| Poster (other) | `thumb` | Own `thumb` only |

### Jellyfin

| App concept | Jellyfin image type | Resolution |
|------------|-------------------|-----------|
| Poster | `Primary` → `Thumb` | Own, then parent, then series |
| Thumbnail (episodes) | `Thumb` → `Primary` | Own only |
| Thumbnail (other) | `Backdrop[0]` → `Thumb` → `Primary` | Own only |
| Poster (other) | `Primary` → `Thumb` | Own, then parent, then series |

## Code locations

- `MediaArtwork.swift` — `url(for:)` fallback
- `MediaItem.swift` — `artworkStyle` determines tile shape
- `PlexModels.swift` — `posterImagePath`, `landscapeImagePath`
- `JellyfinModels.swift` — `posterImageURL`, `landscapeImageURL`
