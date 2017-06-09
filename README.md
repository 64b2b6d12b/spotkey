# SpotKey
SpotKey lets you sort your Spotify Playlists using the song's Key e.g. C Major.

## Requirements
1. You will need to register a new Application at https://developer.spotify.com/my-applications
2. Take note of the Client ID and Client Secret
3. For the 'Redirect URI' you will need to use http://localhost:8082/ (or any other port)
4. In this release you will need to provide the Spotify Playlist ID
5. Create a new file `spotkey.conf` and replace `ID`, `SECRET` and `PLAYLIST` with the values from Steps 1 and 4

```
ID="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
SECRET="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
CALLBACK="localhost"
PORT=8082
PLAYLIST="59ZbFPES4DQwEjBpWHzrtC"
```

## Usage
1. `git clone https://github.com/64b2b6d12b/spotkey.git`
2. `cd spotkey && chmod +x spotkey.sh`
3. `./spotkey.sh`
4. Open `export.csv` in your favourite spreatsheet software and copy the track_uri column rows in to a blank (or existing) Playlist window with either the Spotify client or Spotify web site

## Todo
* Prompt user to select the Playlist
* Create a Playlist using the Spotify Web API rather than using a CSV file
