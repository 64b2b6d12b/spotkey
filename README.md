# SpotKey
SpotKey lets you sort your Spotify Playlists using the song's Key e.g. C Major.

## Requirements
1. You will need to register a new Application at https://developer.spotify.com/my-applications
2. Take note of the Client ID and Client Secret
3. For the 'Redirect URI' you will need to use http://localhost:8082/ (or any other port)
4. In this release you will need to provide the Spotify Playlist ID
5. Create a new file `spotkey.conf` and replace `id` and `secret` with the values from Steps 1

```
id="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
secret="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
callback="localhost"
port=8082
```

## Usage
1. `git clone https://github.com/64b2b6d12b/spotkey.git`
2. `cd spotkey && chmod +x spotkey.sh`
3. `./spotkey.sh`
