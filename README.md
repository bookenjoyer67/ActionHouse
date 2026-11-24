# ActionHouse

Vim-style keyboard control for the auction house in **World of Warcraft: Forever**.

ActionHouse replaces the auction house with a keyboard-first window: move with `j`/`k`, search with `/`, run commands with `:`, and buy, sell, manage, and cancel without reaching for the mouse.

Author: Argus

## Requirements

- World of Warcraft: Forever
- Interface `16001`

This build is for Forever only. It does not target retail or other Classic clients.

## Install

1. Download the latest release zip.
2. Extract it so the folder sits at `Interface/AddOns/ActionHouse` and `ActionHouse.toc` is directly inside it.
3. Restart the game (a `/reload` will not discover a new addon).
4. Open the auction house, or type `/ahv`.

## Quick start

- `/ahv` — show or hide ActionHouse.
- Open the auction house — ActionHouse opens automatically by default.
- `/` — search; a grey suffix previews a recent search, `Tab` accepts it, `Shift-Tab` restores the previous prefix.
- `:blizzard` — hide ActionHouse and return to Blizzard's auction house.
- `/ahv demo` — try every screen with fixture data. Demo mode never sends real auction house actions.
- `/ahv status` — show load, query, throttle, and UI diagnostics.

Type `?` in the window for the full keymap, or `:help`.

## Features

### Buy

- Live auction house search and browse results.
- Drill into an item to see its lots and commodity quantities.
- Sort by name or price; load more results with `m`.
- Bid, buy out, and buy commodity quantities with a quantity prompt.
- Reads the server throttle and reports query errors instead of failing silently.

### Sell

- Lists auctionable items from your bags.
- Posting form for quantity, duration, starting bid, buyout, and unit price.
- Auto-price from the lowest matching listing minus 1c when Blizzard's auto-price is available.
- Shows deposit, expected total, and the price source.
- Handles both item and commodity posting, including Blizzard's post-confirmation dialog.

### Owned and Bids

- Owned auctions with status, cancel fee, and cancellation.
- Active bids with raise-bid and buyout actions.

### Cheap Upgrades

- When the Cheap Upgrades addon is installed, an **Upgrades** tab shows its suggested gear upgrades.
- Results are read from Cheap Upgrades; ActionHouse does not start scans or send extra auction house queries.
- Each row shows the watched spec(s) it upgrades and the equipped item it replaces. Hold `Shift` to show the normal Blizzard item comparison for the selected or hovered upgrade.
- Filter or sort by spec, and press `Enter` on an upgrade to search for that item in Buy. Scan from `/cu` first if the list is empty.

### Interface

- Item icons in every list row.
- Search history with grey inline suggestions in the `/` prompt: `Tab` accepts, `Shift-Tab` restores the previous prefix.
- Vim-style navigation and counts (`5j`, `gg`, `G`, `Ctrl-d`, `Ctrl-u`).
- Visual mode for selecting rows.
- Search, local filters (`quality=epic qty>=20 -bound`), and sorting.
- Command line with completion and history.
- `y`/`n` confirmations for buying, bidding, and cancelling.
- Keyboard capture pauses in combat.
- Window position, history, and settings persist.

## Keymap

| Key | Action |
| --- | --- |
| `j` / `k` | down / up (counts work) |
| `gg` / `G` | first / last row |
| `Ctrl-d` / `Ctrl-u` | half page |
| `Ctrl-f` / `Ctrl-b` | full page |
| `H` / `M` / `L` | top / middle / bottom of the screen |
| `gt` / `gT`, `Tab` / `Shift-Tab` | next / previous tab |
| `/` | search |
| `?` | help |
| `:` | command line |
| `Enter` / `o` | open row or primary action |
| `b` | bid |
| `B` | buyout |
| `p` | post (Sell) |
| `x` / `Delete` | cancel (Owned) |
| `v` / `V` | visual mode / select visible |
| `Esc` | clear pending keys or close |
| `q` / `Q` | close ActionHouse / close the auction house |

Exact behavior depends on the active tab; press `?` in game for the contextual help.

## Commands

| Command | Description |
| --- | --- |
| `:help` | keymap and command reference |
| `:demo [buy\|sell\|owned\|bids]` | fixture data, no real auction house actions |
| `:live` | live Buy view while the auction house is open |
| `:status` | diagnostics |
| `:throttle [reset]` | throttle state; `reset` closes the AH and reloads |
| `:reload` | close the AH and reload the UI |
| `:search <text>` | set search text |
| `:filter <expr>` | local filter |
| `:sort <field> [asc\|desc]` | sort |
| `:set <key>=<value>` | `auto`, `confirm`, `scrolloff` |
| `:buy [qty]` | buy a commodity quantity |
| `:bid [money]` | bid or raise a bid |
| `:raise [money]` | raise the selected bid |
| `:post` | open or submit the sell form |
| `:cancel` | cancel the selected owned auction |
| `:price` | refill the sell form price |
| `:back` | leave item detail or the sell form |
| `:refresh` | refresh the current view |
| `:more` | load more buy results |
| `:upgrades` | Cheap Upgrades suggestions (when installed) |
| `:tab <name>` | switch tab |
| `:b` / `:blizzard` | return to Blizzard's auction house |
| `:q` | close ActionHouse and the auction house |
| `:messages` | recent messages |
| `:version` | version and client |

## Settings

```
:set auto=on|off          open ActionHouse when the auction house opens
:set confirm=always|off   ask y/n before buy, bid, and cancel
:set scrolloff=0-20       rows kept above and below the cursor
```

`confirm=threshold` is accepted but currently behaves like `always`.

## Sell confirmation

ActionHouse does not add its own confirmation before posting. Press `Enter` or `p` to post. If the client requires confirmation, Blizzard's confirmation dialog appears and the post completes when you accept it.

## Troubleshooting

Run `/ahv status` first. It prints the addon version, client build, auction state, throttle state, query state, and UI mode.

- `thr: STUCK` means Forever's auction house throttle has frozen (`IsThrottledMessageSystemReady` stuck `false`). `/reload` now closes the AH first and clears it; `:throttle reset` does the same on demand.
- `:throttle` prints the throttle state and how long it has been unavailable. `:throttle reset` closes the AH and reloads the UI.

- `:probe` — dump client and API details to chat and `ActionHouseDB`.
- `:probedump` — print the last saved probe.
- `:keytest` — show normalized key tokens; `Esc` exits.

These diagnostics are safe to leave enabled; `:probe` does not make mutating auction house calls.

## Compatibility

ActionHouse uses the modern `C_AuctionHouse` API and Blizzard's auction house frames. Other auction house addons (Auctionator, TSM, Auctioneer, etc.) may also hook the same APIs. If you see duplicate windows or missing results, try ActionHouse with the other auction house addon disabled. Please report compatibility problems on the CurseForge project page.

## License

MIT. Copyright (c) 2026 catperson.online. See [LICENSE](LICENSE).

## Links

- CurseForge: https://www.curseforge.com/wow/addons/actionhouse
