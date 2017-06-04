#!/bin/bash

. spotkey.conf

B64="$(echo -ne "${ID}":"${SECRET}" | base64 -w 0)"

#If no refresh token exists, prompt the user to open a URL where they can authorize the app. If refresh token exists, exchange it for access token
if [ ! -e ./refresh_token.json ]; then
REDIRECT_URI="http%3A%2F%2F$CALLBACK%3A$PORT%2F"
SCOPES="playlist-read-private playlist-modify-private user-read-private"
ENCODED_SCOPES=$(echo $SCOPES | tr ' ' '%' | sed s/%/%20/g)
AUTH_ENDPOINT="https://accounts.spotify.com/authorize/?response_type=code&client_id=$ID&redirect_uri=$REDIRECT_URI&scope=$ENCODED_SCOPES"
echo "Please visit: $AUTH_ENDPOINT"
RESPONSE=$(echo -e "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin:*\r\n" | nc -l $PORT)
CODE=$(echo $RESPONSE | grep GET | cut -d ' ' -f 2 | cut -d '=' -f 2)
RESPONSE=$(curl -s https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $B64" -d "grant_type=authorization_code&code=$CODE&redirect_uri=$REDIRECT_URI")
TOKEN=$(echo $RESPONSE | jq -r '.access_token')
echo $RESPONSE | jq -r '.refresh_token' > refresh_token.json
else
REFRESH_TOKEN=$(cat refresh_token.json)
TOKEN=$(curl -s -X POST https://accounts.spotify.com/api/token -H "Content-Type:application/x-www-form-urlencoded" -H "Authorization: Basic $B64" -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN" | jq -r '.access_token')
fi

URL="https://api.spotify.com/v1"
USER=$(curl -s -X GET "${URL}/me" -H "Accept: application/json" -H "Authorization: Bearer ${TOKEN}" | jq -r '.id')


#Download the initial tracks and save the URI, first Artist Name and Track Name in to tracks.csv
COUNT=0
curl -s -X GET "${URL}/users/${USER}/playlists/${PLAYLIST}/tracks" -H "Accept: application/json" -H "Authorization: Bearer ${TOKEN}" > ${COUNT}_tracks.json
jq --raw-output '.items[].track | [.uri, .artists[0].name, .name] | @csv' < ${COUNT}_tracks.json > tracks.csv
#Spotify returns a maximum of 100 tracks in each request. If more than 100 tracks in a Playlist, Spotify provides the next URL to query. Once there are no more next URL's, we will see "null" as the value
NEXT="$(jq --raw-output '.next' < ${COUNT}_tracks.json)"
while [ "$NEXT" != "null" ]
do
(( COUNT++ ))
curl -s -X GET "${NEXT}" -H "Accept: application/json" -H "Authorization: Bearer ${TOKEN}" > ${COUNT}_tracks.json
jq --raw-output '.items[].track | [.uri, .artists[0].name, .name] | @csv' < ${COUNT}_tracks.json >> tracks.csv
NEXT="$(jq --raw-output '.next' < ${COUNT}_tracks.json)"
done

#We need the Track ID's in Comma Seperated Format to query the Audio Features API Endpoint. Spotify allows a maximum of 100 ID's per request
COUNT=0
for i in *_tracks.json; do
jq --raw-output '.items[].track.id' < "$i" | tr '\n' ',' | sed '$ s/,$//' > ${COUNT}_id.txt
(( COUNT++ ))
done

#Sends the Track ID's to the Audio Features API Endpoint in each loop
COUNT=0
FILES='*_id.txt'
for i in $FILES; do
ID="$(cat "${i}")"
curl -s -X GET "${URL}/audio-features/?ids=${ID}" -H "Accept: application/json" -H "Authorization: Bearer ${TOKEN}" > ${COUNT}_features.json
(( COUNT++ ))
done

#Save the values from each Audio Features JSON in to features.csv
FILES='*_features.json'
for i in $FILES; do
jq --raw-output '.audio_features[] | [.uri, .key, .tempo, .mode] | @csv' < "${i}" >> features.csv
done

#Create SQLite tables, insert CSV in to tables, run the SELECT statement
sqlite3 spotkey.db << EOF
CREATE TABLE tracks (track_uri  VARCHAR (36)  PRIMARY KEY NOT NULL, artist VARCHAR (100) NOT NULL, track_name VARCHAR (100) NOT NULL) WITHOUT ROWID;
CREATE TABLE features (track_uri VARCHAR (36) PRIMARY KEY NOT NULL, [key] INTEGER NOT NULL, tempo INTEGER NOT NULL, mode INTEGER NOT NULL) WITHOUT ROWID;
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
