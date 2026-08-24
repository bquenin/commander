# KWReplayAutoSaver (vendored, library part only)

`chunks.py`, `kwchunks.py`, `kwreplay.py`, `utils.py` from
**KWReplayAutoSaver** by BoolBada (forcecore) —
<https://github.com/forcecore/KWReplayAutoSaver>, MIT licence (`LICENSE.txt`).

They parse `.KWReplay` files: the header (map, players, factions) and the
command stream (queue / place / hold / sell / upgrade / power-down orders with
their time codes and template names). Used by `Tools/mine_openers.py` to
extract build orders from public replays without running the game.

The GUI/auto-saver parts of the upstream project are not included.
