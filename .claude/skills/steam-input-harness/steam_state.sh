#!/bin/sh
# steam_state.sh saves Steam's manifest and layouts before installing a manifest over
# them, and puts them back afterwards. Nothing is deleted; a restore moves what it
# displaces under ROOT.
set -eu

USAGE="usage: steam_state.sh install|restore <account id> [manifest to install]"
COMMAND="${1:?$USAGE}"
ACCOUNT="${2:?$USAGE}"

APP="${APP:-480}"
STEAM="${STEAM:-/c/Program Files (x86)/Steam}"
ROOT="$HOME/.steam-input-harness"

# NOTE: SAVED exists only between an install and a restore, so a later install can't
# save the harness's files over Steam's own.
SAVED="$ROOT/saved-$ACCOUNT"
SOURCE="${3:-$(dirname "$0")/game_actions_$APP.vdf}"
MANIFEST="$STEAM/controller_config/game_actions_$APP.vdf"
LAYOUTS="$STEAM/steamapps/common/Steam Controller Configs/$ACCOUNT/config/$APP"

die() {
  echo "$1" >&2
  exit 1
}

[ -d "$STEAM/userdata/$ACCOUNT" ] || die "no account $ACCOUNT in $STEAM/userdata"

case "$COMMAND" in
install)
  [ -f "$SOURCE" ] || die "no manifest at $SOURCE; the harness writes its own when run"
  mkdir -p "$ROOT"
  if [ -d "$SAVED" ]; then
    echo "keeping the state already saved in $SAVED"
  else
    # NOTE: The copy is renamed into place so that SAVED only ever means a whole save.
    PARTIAL="$(mktemp -d "$ROOT/partial.XXXXXX")"
    [ ! -e "$MANIFEST" ] || cp "$MANIFEST" "$PARTIAL/"
    [ ! -d "$LAYOUTS" ] || cp -R "$LAYOUTS" "$PARTIAL/layouts"
    mv "$PARTIAL" "$SAVED"
    echo "saved Steam's state in $SAVED"
  fi
  cp "$SOURCE" "$MANIFEST"
  echo "installed $SOURCE"
  ;;
restore)
  [ -d "$SAVED" ] || die "nothing saved in $SAVED"
  DISPLACED="$ROOT/$(date +%Y%m%d-%H%M%S)"
  mkdir "$DISPLACED"
  echo "moving the current state to $DISPLACED"
  [ ! -e "$MANIFEST" ] || mv "$MANIFEST" "$DISPLACED/"
  [ ! -d "$LAYOUTS" ] || mv "$LAYOUTS" "$DISPLACED/layouts"
  [ ! -e "$SAVED/game_actions_$APP.vdf" ] || cp "$SAVED/game_actions_$APP.vdf" "$MANIFEST"
  [ ! -d "$SAVED/layouts" ] || cp -R "$SAVED/layouts" "$LAYOUTS"
  mv "$SAVED" "$DISPLACED/restored"
  echo "restored Steam's state"
  ;;
*)
  die "$USAGE"
  ;;
esac
