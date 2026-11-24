# Changelog

## Unreleased

- Close the auction house before `ReloadUI` runs, so the first `/reload` clears a stuck auction house throttle instead of needing a second reload or a logout.
- Detect Forever's stuck auction house throttle (`IsThrottledMessageSystemReady` stuck `false`) and surface `thr: STUCK` with a reload/reset instruction instead of waiting forever.
- Add `:throttle reset` and `:reload` to safely close the AH and reload the UI.
- Gate "load more" requests on the throttle and share throttle checks across Buy, Sell, Owned, and Bids.
- Defer Sell auto-price searches until `GetItemKeyInfo` is cached, and use `SendSellSearchQuery` for equipment, avoiding searches Forever can ignore and leave pending.
- Add `:throttle` diagnostics.

## 0.5.0

First public release.

- Vim-style keyboard control for the World of Warcraft: Forever auction house.
- Live Buy: server search, item drill-in, sorting, more results, bids, buyouts, and commodity quantity prompts.
- Sell: bag list, posting form, auto-price, deposit and expected total, duration and quantity, and item and commodity posting.
- Owned: auction list, status, cancel fee, and cancellation.
- Bids: active bids, raise bid, and buyout.
- Demo mode with fixture data that never touches the real auction house.
- Command line with completion and history.
- Configurable auto-open, confirmations, and scrolloff.
- Combat pauses keyboard capture.
- Item and commodity posting use the client's Blizzard post-confirmation path.
- Added README, changelog, MIT license, and CurseForge metadata.
