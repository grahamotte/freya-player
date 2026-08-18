# TODO

- [ ] 
- [ ] 
- [ ] 
- [ ] 
- [ ] 
- [x] on the macos app (and maybe others), if you go to the lirbraries page and scroll to the right all the way for one of the libraries, the last item touches the edge of the screen with no padding
- [x] the macos app, on the libraries page (and maybe other pages), there doesn't seem to be enough padding at the bottom? it should be the same as the left padding between the lists and the edge of the window so that the manage and bout buttons sit squarely in the bottom left corner
- [x] can you replace the logo/icon with the v2 version in the asssets dir?
- [x] when running mise start, we shoudl start the macos app, then tvos, then ipados in that order
- [x] we added a macos version there was no .plist for that. can we add that and anything else missing which would prevent it from being submitted?
- [x] when a piece of media end, the player just hangs there on black. we should close the player and return to the media item we were viewing when it's done
- [x] for the lists on tv series and tv season, we should auto scroll to most recently unseen item, so the user doesn't need to scroll down a long list
- [x] bug: after you click the play button it changes to a spinner, but the moment before the media starts playing, it goes back to "play", making it look like the play failed. we should debounce this with some sort of set timeout
- [x] the watch progress button should always be after the play button, to the right of it
- [x] give the seen control button a yellow hue like the progress and check circle has to tie the themes together
