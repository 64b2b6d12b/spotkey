#!/bin/bash

. spotkey.conf

B64="$(echo -ne ${ID}:${SECRET} | base64 -w 0)"
#Generate Spotify Access Token as per https://developer.spotify.com/web-api/authorization-guide/#client-credentials-flow
TOKEN="$(curl -s -X POST https://accounts.spotify.com/api/token -H "authorization: Basic ${B64}" -H "content-type: application/x-www-form-urlencoded" -d grant_type=client_credentials | jq --raw-output '.access_token')"
URL="https://api.spotify.com/v1"

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
jq --raw-output '.audio_features[] | [.uri, .key, .tempo] | @csv' < "${i}" >> features.csv
done

rm -f ./*.json && rm -f ./*.txt

#Create SQLite tables, insert CSV in to tables, run the SELECT statement
sqlite3 spotkey.db << EOF
CREATE TABLE tracks (track_uri  VARCHAR (36)  PRIMARY KEY NOT NULL, artist VARCHAR (100) NOT NULL, track_name VARCHAR (100) NOT NULL) WITHOUT ROWID;
CREATE TABLE features (track_uri VARCHAR (36) PRIMARY KEY NOT NULL, [key] INTEGER NOT NULL, tempo INTEGER NOT NULL) WITHOUT ROWID;
.mode csv
.import tracks.csv tracks
.import features.csv features
.headers on
.output export.csv
SELECT tracks.track_uri, tracks.artist, tracks.track_name, features."key", features.tempo FROM tracks INNER JOIN features ON tracks.track_uri = features.track_uri ORDER BY key ASC, tempo ASC;
EOF

rm -f tracks.csv && rm -f features.csv
