# Changelog

## Unreleased

- Close the auction house on `PLAYER_LOGOUT` so `/reload` clears the auction house throttle the same way logging out does.
- Detect Forever's stuck auction house throttle (`IsThrottledMessageSystemReady` stuck `false`) and surface `thr: STUCK` with logout/restart instructions instead of waiting forever.
- Gate "load more" requests on the throttle and share throttle checks across Buy, Sell, Owned, and Bids.
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
