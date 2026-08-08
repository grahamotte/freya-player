# Privacy Policy

Effective date: 2026-04-01

Freya Player is an app for tvOS that connects to Plex and Jellyfin servers chosen by the user. This app is developed by Graham Otte.

Freya Player is only a client. It does not include, host, provide, or unlock any content or streaming catalog of its own. To use it, you must connect your own **personal** Plex or Jellyfin server.

## Summary

Freya Player does not run its own developer backend, does not include advertising, and does not use third-party analytics or crash reporting SDKs. The app stores some connection and preference data on your device and communicates directly with the Plex and Jellyfin services you choose to use.

The developer of Freya Player does not host your media, does not log your media library, and does not have access to the content stored on your server. Any browsing or playback happens directly between the app on your device and the server you choose to connect.

## Information Freya Player processes

### Information stored on your device

To keep you signed in and preserve app settings, Freya Player may store the following on your device:

- Plex or Jellyfin access tokens
- selected server details, such as a server identifier or server URL
- Jellyfin user ID and display name
- locally generated client or device identifiers used when talking to provider APIs
- library order, hidden libraries, filters, sort options, and similar app preferences

Access tokens are stored in the system Keychain when available. Other settings are stored in standard on-device app storage.

### Information sent to Plex or Jellyfin

When you connect a service, Freya Player sends data directly to the provider you chose:

- For Plex, Freya Player communicates with `plex.tv` for sign-in and server discovery, and with your Plex Media Server for browsing and playback.
- For Jellyfin, Freya Player communicates with the Jellyfin server URL you enter.

Depending on the feature you use, these requests may include:

- your sign-in credentials or provider-issued access tokens
- your chosen server address
- client or device identifiers and app version information
- media browsing requests
- playback state and progress, including resume position and watched or unwatched status
- stream selection information such as audio and subtitle choices

Freya Player uses this information only to provide browsing, playback, resume, and watch-status features. The developer does not receive this data on separate developer-operated servers.

## No developer access to your content

Freya Player has no built-in content service and no connection to any content by itself. You must provide your own **personal** Plex or Jellyfin server.

The app may request media metadata and stream URLs from the server you configure so it can browse and play content on your device. However, the developer of Freya Player does not receive, store, review, control, monitor, or otherwise have access to your media files or library contents through an operated service, because Freya Player does not operate one.

You are solely responsible for the content made available through the server you connect to Freya Player, including whether you have the right to access, stream, or view that content. The developer of Freya Player does not accept responsibility for the content you choose to view with the app.

## What Freya Player does not do

Freya Player does not:

- sell your personal information
- use advertising SDKs
- track you across apps or websites
- collect precise location information
- request access to contacts, photos, camera, or microphone

## Third-party services

If you use Plex or Jellyfin, your use of those services is also governed by their own privacy practices and terms. Freya Player cannot control how Plex, Jellyfin, or the operator of a Jellyfin server handles your data.

## Data retention and deletion

Data stored locally by Freya Player remains on your device until you remove it. You can deactivate a connected server in the app to remove stored connection details and tokens for that server. Some local preferences or identifiers may remain on the device until the app or its data is removed by the platform.

Because Freya Player does not maintain developer-run user accounts or backend storage, the developer generally cannot independently access, export, or delete data held by Plex, Jellyfin, or your own media server. To revoke access or delete provider-side data, use the relevant Plex or Jellyfin account or server controls.

## Children's privacy

Freya Player is not directed to children under 13 and is not designed to knowingly collect personal information from children.

## Changes to this policy

This Privacy Policy may be updated from time to time. When it changes, the updated version will be posted at this URL with a new effective date.

## Contact

If you have questions about this Privacy Policy, contact:

Graham Otte
graham.otte@gmail.com
