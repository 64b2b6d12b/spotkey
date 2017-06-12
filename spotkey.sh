#!/usr/bin/env bash

oauth2 () {
source spotkey.conf
b64=$(echo -ne "${id}":"${secret}" | base64 -w 0)
#If no refresh token exists, prompt the user to open a URL where they can authorize the app. If refresh token exists, exchange it for access token
if [ ! -e ./refresh_token.json ]
then
  redirect_uri="http%3A%2F%2F$callback%3A$port%2F"
  scopes=$(echo "playlist-read-private playlist-modify-private user-read-private" | tr ' ' '%' | sed s/%/%20/g)
  auth_endpoint="https://accounts.spotify.com/authorize/?response_type=code&client_id=$id&redirect_uri=$redirect_uri&scope=$scopes"
  echo "Please visit: $auth_endpoint"
  response=$(echo -e "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin:*\r\n" | nc -l "${port}")
  code=$(echo "${response}" | grep GET | cut -d ' ' -f 2 | cut -d '=' -f 2)
  response=$(curl -s https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $b64" -d "grant_type=authorization_code&code=$code&redirect_uri=$redirect_uri")
  token=$(echo "${response}" | jq -r '.access_token')
  echo "${response}" | jq -r '.refresh_token' > refresh_token.json
else
  refresh_token=$(cat refresh_token.json)
  token=$(curl -s -X POST https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $b64" -d "grant_type=refresh_token&refresh_token=$refresh_token" | jq -r '.access_token')
fi
}

oauth2

url="https://api.spotify.com/v1"
user=$(curl -s -X GET "${url}/me" -H "Accept: application/json" -H "Authorization: Bearer ${token}" | jq -r '.id')

select_playlist () {
curl -s -X GET "${url}/me/playlists" -H "Authorization: Bearer ${token}" > playlists.json
available_playlists=$(jq -r '.items[].name' < playlists.json)
echo "Your available playlists are:"
echo "---------------------"
echo "${available_playlists}"
echo "---------------------"
echo "Please copy and paste the name of the playlist you would like to sort and then press ENTER:"
read selected_playlist
playlist=$(jq -r ".items[] | select(.name == \"${selected_playlist}\") | .id" < playlists.json)
rm -f ./playlists.json
}

select_playlist

tracks () {
#Download the initial tracks and save the URI, first Artist Name and Track Name in to tracks.csv
count=0
curl -s -X GET "${url}/users/${user}/playlists/${playlist}/tracks" -H "Accept: application/json" -H "Authorization: Bearer ${token}" > "${count}"_tracks.json
jq -r '.items[].track | [.uri, .artists[0].name, .name] | @csv' < "${count}"_tracks.json > tracks.csv
#Spotify returns a maximum of 100 tracks in each request. If more than 100 tracks in a Playlist, Spotify provides the next URL to query. Once there are no more next URL's, we will see "null" as the value
next=$(jq -r '.next' < "${count}"_tracks.json)
while [ "$next" != "null" ]
do
  (( count++ ))
  curl -s -X GET "${next}" -H "Accept: application/json" -H "Authorization: Bearer ${token}" > "${count}"_tracks.json
  jq -r '.items[].track | [.uri, .artists[0].name, .name] | @csv' < "${count}"_tracks.json >> tracks.csv
  next=$(jq -r '.next' < "${count}"_tracks.json)
done
}

tracks

features () {
#We need the Track ID's in Comma Seperated Format to query the Audio Features API Endpoint. Spotify allows a maximum of 100 ID's per request
count=0
files="*_tracks.json"
for i in $files
do
  jq -r '.items[].track.id' < "$i" | tr '\n' ',' | sed '$ s/,$//' > "${count}"_id.txt
  (( count++ ))
done
#Sends the Track ID's to the Audio Features API Endpoint in each loop
count=0
files="*_id.txt"
for i in $files
do
  id="$(cat "${i}")"
  curl -s -X GET "${url}/audio-features/?ids=${id}" -H "Accept: application/json" -H "Authorization: Bearer ${token}" > "${count}"_features.json
  (( count++ ))
done
#Save the values from each Audio Features JSON in to features.csv
files="*_features.json"
for i in $files
do
  jq -r '.audio_features[] | [.uri, .key, .tempo, .mode, .danceability, .energy, .loudness, .speechiness, .acousticness, .liveness, .valence, .duration_ms] | @csv' < "${i}" >> features.csv
done
}

features

csv2sqlite3 () {
#Create SQLite tables, insert CSV in to tables, run the SELECT statement
sqlite3 << EOF
CREATE TABLE tracks (track_uri  VARCHAR (36)  PRIMARY KEY NOT NULL, artist VARCHAR (100) NOT NULL, track_name VARCHAR (100) NOT NULL) WITHOUT ROWID;
CREATE TABLE features (track_uri VARCHAR (36) PRIMARY KEY NOT NULL, [key] INTEGER NOT NULL, tempo INTEGER NOT NULL, mode INTEGER NOT NULL, danceability REAL NOT NULL, energy REAL NOT NULL, loudness REAL NOT NULL, speechiness REAL NOT NULL, acousticness REAL NOT NULL, liveness REAL NOT NULL, valence REAL NOT NULL, duration_ms INTEGER NOT NULL) WITHOUT ROWID;
.mode csv
.import tracks.csv tracks
.import features.csv features
.headers on
.output export.csv
ALTER TABLE features ADD COLUMN pitch_class VARCHAR (20);
UPDATE features SET pitch_class = 'C Major' WHERE "key" = 0 AND mode = 1;
UPDATE features SET pitch_class = 'C Minor' WHERE "key" = 0 AND mode = 0;
UPDATE features SET pitch_class = 'C# Major' WHERE "key" = 1 AND mode = 1;
UPDATE features SET pitch_class = 'C# Minor' WHERE "key" = 1 AND mode = 0;
UPDATE features SET pitch_class = 'D Major' WHERE "key" = 2 AND mode = 1;
UPDATE features SET pitch_class = 'D Minor' WHERE "key" = 2 AND mode = 0;
UPDATE features SET pitch_class = 'D# Major' WHERE "key" = 3 AND mode = 1;
UPDATE features SET pitch_class = 'D# Minor' WHERE "key" = 3 AND mode = 0;
UPDATE features SET pitch_class = 'E Major' WHERE "key" = 4 AND mode = 1;
UPDATE features SET pitch_class = 'E Minor' WHERE "key" = 4 AND mode = 0;
UPDATE features SET pitch_class = 'F Major' WHERE "key" = 5 AND mode = 1;
UPDATE features SET pitch_class = 'F Minor' WHERE "key" = 5 AND mode = 0;
UPDATE features SET pitch_class = 'F# Major' WHERE "key" = 6 AND mode = 1;
UPDATE features SET pitch_class = 'F# Minor' WHERE "key" = 6 AND mode = 0;
UPDATE features SET pitch_class = 'G Major' WHERE "key" = 7 AND mode = 1;
UPDATE features SET pitch_class = 'G Minor' WHERE "key" = 7 AND mode = 0;
UPDATE features SET pitch_class = 'G# Major' WHERE "key" = 8 AND mode = 1;
UPDATE features SET pitch_class = 'G# Minor' WHERE "key" = 8 AND mode = 0;
UPDATE features SET pitch_class = 'A Major' WHERE "key" = 9 AND mode = 1;
UPDATE features SET pitch_class = 'A Minor' WHERE "key" = 9 AND mode = 0;
UPDATE features SET pitch_class = 'A# Major' WHERE "key" = 10 AND mode = 1;
UPDATE features SET pitch_class = 'A# Minor' WHERE "key" = 10 AND mode = 0;
UPDATE features SET pitch_class = 'B Major' WHERE "key" = 11 AND mode = 1;
UPDATE features SET pitch_class = 'B Minor' WHERE "key" = 11 AND mode = 0;
SELECT tracks.track_uri, tracks.artist, tracks.track_name, features.pitch_class, features.tempo FROM tracks INNER JOIN features ON tracks.track_uri = features.track_uri ORDER BY "key" ASC, mode DESC, tempo ASC;
EOF
}

csv2sqlite3

clean () {
rm -f ./*_features.json && rm -f ./*_id.txt && rm -f ./*_tracks.json
rm -f ./features.csv && rm -f ./tracks.csv
}

clean
