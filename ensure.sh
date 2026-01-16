#!/usr/bin/env bash

set -eu
shopt -s nullglob

function fail() {
	echo "Fail:" "$@"
	exit 1
}

echo "Syncing .config"
pushd .config
{
	for dir in *; do
		test -d "$dir" || fail ".config may only contain dirs"
		echo "Syncing dir $dir"
		! test -e "$HOME/.config/$dir" || test -L "$HOME/.config/$dir" || fail ".config/$dir should either already be a existing symlink, or not exist!"
		ln -nsf "$PWD/$dir" "$HOME/.config/$dir"
	done
}
popd

echo "Syncing wallpapers"
# Those are downloaded from patreon/my personal photos, I don't want to distribute them.
# Encryption is intentionnaly weak for shorter encrypted versions, feel free to brute-force it, lol.
WALLPAPER_KEY=$(pass dotfiles/wallpapers)
WALLPAPERS=$PWD/wallpapers

function enc_data() {
	nix run "nixpkgs#openssl" -- enc -aes-128-cbc -pbkdf2 -pass "pass:$WALLPAPER_KEY" "$@"
}
function dec_data() {
	nix run "nixpkgs#openssl" -- enc -aes-128-cbc -pbkdf2 -d -pass "pass:$WALLPAPER_KEY" "$@"
}
function enc_name() {
	echo "$1" | enc_data -nosalt -A -a | tr '+/' '-_'
}
function dec_name() {
	echo "$1" | tr -- '-_' '+/' | dec_data -nosalt -A -a
}

echo "Copying stored wallpapers"
mkdir -p "$HOME/.config/swww"
ln -nsf "$HOME/.config/swww" "$HOME/.config/awww"
pushd wallpapers
{
	for name in *; do
		rname=$(dec_name "$name")
		if ! test -f "$HOME/.config/swww/$rname"; then
			echo "New wallpaper: $rname"
			rsync -a "$name" "$HOME/.config/swww/$rname"
		fi
	done
}
popd

echo "Copying new wallpapers"
pushd "$HOME/.config/swww"
{
	for name in *; do
		rname=$(enc_name "$name")
		if ! test -f "$WALLPAPERS/$rname"; then
			echo "New wallpaper: $name"
			cat "$name" | enc_data > "$WALLPAPERS/$rname"
		fi
		# rsync -a "$name" "$WALLPAPERS/
	done
}
popd
# enc_name() { echo "$1" | openssl enc -aes-128-cbc -pbkdf2 -a -A -pass "pass:$KEY"; }
# dec_name() { echo "$1" | openssl enc -aes-128-cbc -pbkdf2 -a -A -d -pass "pass:$KEY"; }
