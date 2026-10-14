# The Last Lantern

*The night is endless. Your light is not.*

A bullet-heaven roguelite in the style of *Vampire Survivors* and *Brotato*. You are the last lantern-bearer in an endless night. Hordes of shadow creatures close in while your weapons fire on their own. Collect soul-gems, level up, build a combo of weapons and relics, and survive 12 minutes until the Hollow King rises. Defeat him and dawn breaks, or keep going into the Endless Night.

## What's in the game

- **7 weapons**: Ember Bolt, Sun Halo, Lantern Pulse, Storm Arc, Moon Scythe, Lantern Seeds, Frost Shards. Each has 6 levels.
- **12 relics (passives)**: damage, cooldown, area, extra projectiles, armor, luck, magnet, and more. *Bright Oil* ties into the light mechanic: enemies inside your lantern's light take extra damage.
- **7 playable Keepers**, each with a different starting weapon and stats. The other 6 unlock through achievements.
- **4 boss fights**: the Ashen Warden, the Hollow Choir, the Warden reborn, and the Hollow King. Bosses use dashes, bullet rings, spirals, and summons.
- **Elite enemies and treasure chests**, plus horde events every few minutes.
- **The Sanctum**: a permanent upgrade shop paid for with Embers earned each run, so every run makes you stronger.
- **14 achievements**, wired for Steam achievements.
- **Endless mode** after the victory.
- **Full controller support**, including menu navigation, so it is ready for Steam Deck.
- Settings for volume, music, screen shake, damage numbers, and fullscreen. Progress saves automatically.
- **No asset files.** All graphics, music, and sound effects are generated in code, so there is nothing to license.

## Play it now

```bash
npm install
npm start              # runs as a desktop app (Electron)
```

Or open `game/index.html` in Chrome to play in a browser.

**Controls:** WASD, arrow keys, or the left stick to move. Weapons fire automatically. Esc, P, or Start pauses. 1–4 pick level-up cards. F11 toggles fullscreen.

## Build for Steam

```bash
npm run dist:win     # -> dist/win-unpacked/   (Windows build)
npm run dist:linux   # -> dist/linux-unpacked/ (Linux / Steam Deck)
```

Steam expects a folder, not an installer, so each build is a plain folder to upload.

## How to get it on Steam (checklist)

1. **Steamworks account.** Sign up at <https://partner.steamgames.com>. The Steam Direct fee is **$100 per game** and is recouped after $1,000 in sales. You'll need tax and bank details.
2. **Get your App ID.** Steamworks gives you one. Put it in a file called `steam_appid.txt` next to the game `.exe` for local testing. Also change `appId` in `package.json` to your own reverse-domain name.
3. **Achievements.** In Steamworks, go to *Stats & Achievements* and create one achievement per entry below. Use these **exact API names**, because the game already sends them:
   `ACH_FIRST_NIGHT, ACH_SURVIVE_5, ACH_SURVIVE_10, ACH_BOSS, ACH_DAWN, ACH_ENDLESS_20, ACH_KILLS_1000, ACH_KILLS_TOTAL, ACH_LEVEL_30, ACH_MAX_WEAPON, ACH_ARSENAL, ACH_RICH, ACH_NO_HIT_3, ACH_ALL_CHARS`
   The names and descriptions players see are in `ACHIEVEMENTS` in `game/game.js`.
4. **Store page assets.** You need capsule images (header 920×430, small 462×174, main 1232×706, vertical 748×896, library 600×900), at least 5 screenshots, and ideally a 30–60 second trailer. Screenshots are easy: play the game and press your OS screenshot key.
5. **Upload the build** with SteamPipe (the `steamcmd` ContentBuilder in the Steamworks SDK). Upload the `dist/win-unpacked` folder as the Windows depot and `dist/linux-unpacked` as the Linux depot. Set the launch option to `The Last Lantern.exe` (Windows) or `the-last-lantern` (Linux).
6. **"Coming Soon" page early.** Valve requires the store page to be live for at least 2 weeks before release, and wishlists drive launch visibility. Put the page up as soon as you have art.
7. **Price.** Survivors-likes typically sell for **$2.99–$4.99**. A launch discount of 10–20% helps.

### Marketing that works for this genre
- Short, chaotic gameplay clips (hundreds of enemies, big upgrade moments) on TikTok, YouTube Shorts, and Reddit (r/IndieGaming, r/roguelites, r/VampireSurvivors).
- Steam Next Fest: enter with a free demo. A demo build can simply cap runs at the first boss.
- Send keys to YouTubers who cover survivors-likes. The genre has a dedicated audience.

No game is guaranteed to sell. Wishlists before launch are the best predictor, so start building the store page and posting clips early.

## Ideas for updates after launch

Content updates keep games in this genre selling: new maps (each with a new night palette), weapon evolutions (max weapon + matching relic = super weapon), more Keepers, a curse/difficulty slider, and a bestiary.

## Project layout

```
game/index.html   UI screens (menus, level-up, shop, etc.)
game/style.css    UI styling
game/game.js      The whole game: engine, content, audio, saves
electron/         Desktop wrapper + Steam achievement bridge
package.json      Build config (electron-builder)
```

Balance numbers are near the top of `game/game.js`: `ENEMY_TYPES`, `BOSSES`, `BOSS_SCHEDULE`, `WEAPONS`, `PASSIVES`, `CHARS`, `SHOP`.
