# Search Page

The Search Page searches the locally cached media titles across every visible library on one server without contacting the server or building a persisted search index.

It contains a focused search control that accepts keyboard entry and system dictation. tvOS uses the native system search presentation. Other platforms place a Back button and a search input together in one top row, with the input filling the remaining width. The server name is not displayed on this page. Results update after every text change, use fuzzy matching to allow omitted or mistyped characters, exclude matches below a reasonable confidence threshold, and appear in confidence order.

Results appear as large boxes over the same full-screen animated ambient background as the Home Page. Each box uses equal padding on every edge and contains a fixed square artwork area followed by the media title, release date when available, a truncated description, and remaining space. Artwork is centered and aspect-fit in that area: landscape images fill its width and portrait images fill its height. Rounding applies to the actual image bounds, and every preview uses the same corner radius. The fixed artwork area keeps every title aligned. Matched title ranges use strong weight and contrast against subdued unmatched text. Search controls and result boxes share aligned page margins.

Selecting a result opens that media item's page through the normal app navigation stack. Navigating back from the item returns to the Search Page with the current query intact.
