#!/bin/bash
#Replace CLIENT_ID & CLIENT_SECRET with values generated from https://developer.spotify.com/my-applications
CLIENT_ID="00000000000000000000000000000000"           
CLIENT_SECRET="00000000000000000000000000000000"               
BASE64_CREDENTIALS="$(echo -ne ${CLIENT_ID}:${CLIENT_SECRET} | base64 -w 0)"

#Generate Spotify Access Token as per https://developer.spotify.com/web-api/authorization-guide/#client-credentials-flow
ACCESS_TOKEN="$(curl -s -X POST https://accounts.spotify.com/api/token -H "authorization: Basic ${BASE64_CREDENTIALS}" -H "content-type: application/x-www-form-urlencoded" -d grant_type=client_credentials | jq --raw-output '.access_token')"

SPOTIFY_USER=""
PLAYLIST_ID=""

STARTING_FILE=0

#Get first 100 tracks due to Spotify's restriction
curl -s -X GET "https://api.spotify.com/v1/users/${SPOTIFY_USER}/playlists/${PLAYLIST_ID}/tracks" -H "Accept: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" > ${STARTING_FILE}_${PLAYLIST_ID}.json
jq --raw-output '["track_uri","artist","track"], (.items[].track | [.uri, .artists[0].name, .name]) | @csv' < ${STARTING_FILE}_${PLAYLIST_ID}.json >> ${PLAYLIST_ID}.csv

#If there are more than 100 tracks Spotify's will return the next URL, if less than 100 tracks, Spotify will return "null"
NEXT_URL="$(jq --raw-output '.next' < ${STARTING_FILE}_${PLAYLIST_ID}.json)"
while [ "$NEXT_URL" != "null" ]
do
(( STARTING_FILE++ ))
curl -s -X GET "${NEXT_URL}" -H "Accept: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" > ${STARTING_FILE}_${PLAYLIST_ID}.json
jq --raw-output '.items[].track | [.uri, .artists[0].name, .name] | @csv' < ${STARTING_FILE}_${PLAYLIST_ID}.json >> ${PLAYLIST_ID}.csv
NEXT_URL="$(jq --raw-output '.next' < ${STARTING_FILE}_${PLAYLIST_ID}.json)"
done
