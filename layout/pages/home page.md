# Home Page

The Home Page is the authenticated landing page, currently implemented as the Libraries page.

It is one vertically scrolling stack containing, in order:

1. A header row containing the connected server name as a prominent left-aligned page title and a search button on the right. The search button uses the same size and visual style as the Management Buttons Component, contains a magnifying-glass icon and the word "Search," and opens the [Search Page](<search page.md>) for the server. On tvOS, moving focus up from the first item in the top library shelf focuses Search.
2. One [Library Shelf Component](<../components/library shelf component.md>) for each non-hidden library on that server.
3. The [Management Buttons Component](<../components/management buttons component.md>) at the bottom.
