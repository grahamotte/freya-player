# JFSF - Jellyfin setup form has inconsistent field sizing, focus, and port handling

## user value

As a user adding a Jellyfin server, I want a setup form that looks native, keeps its fields a consistent size, and moves me through the form sensibly, so that connecting is predictable and pleasant on every Apple platform.

## Problem description

The Jellyfin setup form has several distinct issues. They are grouped by the devices they affect.

### All platforms

- When Connect is pressed, a spinner appears but the form stays on screen. The form should be replaced with a centered "connecting" indicator so the form is no longer visible while connecting.
- Changing the protocol does not autofill the port. Changing from HTTPS to HTTP should set the port to the Jellyfin HTTP port (8096), and changing from HTTP to HTTPS should set the port to 443. Today only the placeholder changes; the port value stays as entered/defaulted.
- Changing the port should not change the protocol. Only changing the protocol should change the port.

### tvOS

- Field text is a different size depending on its state: entered text is larger than the placeholder, the field grows when text is entered, and text is sometimes very small. The text should be one consistent size across placeholder, entered, and highlighted states.
- Text is not consistently vertically centered in the field.
- The field itself changes size; it should stay the same size whether or not it contains text.
- After finishing the full-screen editor and pressing Done, focus returns to the address field instead of the Connect button. Finishing the form should land focus on Connect.

### iOS, iPadOS, and Mac Catalyst (non-tvOS)

- The form fields look non-native and dated, like web browser form fields. They should use the modern rounded pill style (the newer iOS 27 look) and look consistent across iPad, iPhone, and Mac.

## Status, notes, context, etc

- Form source: `apps/apple/App/Pages/Setup/Components/JellyfinSetupContent.swift`.
- The port placeholder already varies with protocol (`https` → `443`, otherwise `8096`), but the bound `port` value does not update when the protocol changes.
- Jellyfin's own default ports are 8096 (HTTP) and 8920 (HTTPS), but the app and the user's expectation use 443 for HTTPS.

## Prompts

> Okay, there's like multiple issues with the input form for Jellyfin, and I just want to record them in cards. Just one single card with all the issues. I'm not gonna fix them now because they're surprisingly difficult to fix. So let's just record them and then we can fix them later. So The first one is that when I click connect on Jellyfin, it adds this like spinner loader thing, but keeps the form there. You should remove the form and just have. A spinner in the center of the screen, or you know, some like the screen is waiting to connect sort of thing. You shouldn't show the form anymore. The next current issue. T V O S that earlier issue was I think for all platforms it does it. But on T V O S we have some very specific T V O S issues. Let's so I think that was the only the spinner thing was the only issue for all platforms. Now I'm gonna have platform specific issues. TVOS. When text is entered into fields, it is larger than the placeholder text. That is a current issue on the form. Also, the form fields get bigger when text is entered, but Also, weirdly, sometimes text is really small in the fields. The text size and the form fields are all over the place. The text should always be the same size, no matter if it is highlighted or Entered in or a placeholder value, it should always be the same size, should always be vertically centered in the input field, which it is not always vertically centered in the input field. And the input. Field should always be the same size as well. Always, this should be the same size whether text is in it or not. The input fields do seem to work. But yeah, they have that issue. The other issue, when you change the protocol from HTTPS to HTTP, it should change the port to the Jellyfin port, which I think is 8086, and it doesn't do that. Similarly, when you go from HB to HPS, just change the port to 443 and now it just defaults. It doesn't There's no hooking up with this, which sucks. When you change the port, though, it should not change the protocol. Only when you change the protocol should it change the port. So, yeah, there's mostly sizing weirdness there. I think that is the only issue for TVOs. Now, for Mac OS, the and I believe this is also for. iPhone and iPad as well. I'll check real quick. But these are basically all the non-TVOS devices have this issue. The issue is that the form field Look really bad. They don't feel native. They feel like a web browser form field or something. They should have the like rounded pill. Shapes and stuff like that, which is the like newer iOS 27 style. On iPad, iPhone, and Mac, the four. All look the same, and that's fine. It's fine if they look the same, but they should look more modern, they look very old, and they should just look better. I think all the entering works, it still has that spinner issue that applies to all. But that's fine. Um, oh, I have one more issue with TBOS. When you finish filling out all the fields and you click done on the like full screen editor that it has, uh It puts your input on the address input, not on the connect button. So you have to click all the way down to the connect button to connect, even though you just finished the whole form. So when you click done on that, like listen. Of inputs, it should put you on the connect button, not on the address fields. Okay, I think that is all the issues I know of with this. Just make a card, list them out clearly. I know it was a lot of rambling and stuff, but just make a card, listen up clearly, and then we can maybe address it in the future. Be sure to specify what device different things are affecting because it can get confusing. Hold on.

Created a single problem card in `1 - Problems to Solve/` listing all reported Jellyfin setup form issues, grouped by affected device.

> The HTTP switching to A 8086 and HPS to 443 is something that affects all platforms and should be fixed. We should autofill the port when we change the protocol, but not the other way around.

Moved the protocol-to-port autofill issue from the tvOS group to the all-platforms group.
