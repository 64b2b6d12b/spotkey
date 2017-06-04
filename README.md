# SpotKey
SpotKey lets you sort your Spotify Playlists using the song's Key e.g. C Major.

## Requirements
1. You will need to register a new Application at https://developer.spotify.com/my-applications
2. Take note of the Client ID and Client Secret
3. For the 'Redirect URI' you will need to use http://localhost:8082/ (or any other port)
4. Create a new file `spotkey.conf` and replace `ID` and `SECRET` with the values from Step 1

```
ID="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
SECRET="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
CALLBACK="localhost"
PORT=8082
```
