# Changelog

## 1.1.0

- Route records: the place numbers in front of each score were hard to read on the parchment; they are darker now.

## 1.0.1

- Route names showed an empty box instead of the arrow between the two places; they now read "Orgrimmar » Sun Rock".

## 1.0.0

First full release. Found a bug or have an idea? https://github.com/Koslowsky1337/Pastime/issues

- Goblin Slots is now a five-reel machine with three rows and five lines. The coin is wild, and every win pays more than your bet; about four spins in ten win. The reels take their time, and when a line is building up, the next reel keeps you waiting while the matching symbols glow.
- Goblin Poker replaces Draw Poker: you play five cards against the goblin, swap once, then raise or fold.
- Goblin Roulette replaces Goblin Baccarat: you place your own chips on numbers, dozens and the even chances.
- Tavern Hold'em is now a table tournament: you buy in, all four start with the same chips, nobody can bet more than they have, there is an all-in button, and players who run out of chips are gone. Win the table or get up between hands with your chips.
- Zeppelins and boats: the window now opens when the ship departs, no longer while you wait at the tower or dock.
- The game list scrolls two rows per mouse-wheel step instead of half a page.

## 1.0.0-beta3

Please report anything odd: https://github.com/Koslowsky1337/Pastime/issues

- Five new games of chance, each with its own goblin gold and scored like Goblin Blackjack (your highest gold counts when you cash out or go broke): Goblin Slots, Draw Poker, Higher or Lower, Goblin Baccarat and Tavern Hold'em against three computer opponents. Pastime now has 24 games.
- New "Rules" button next to the board: pauses the game and explains the goal and the controls.
- Pause and the arrival dialog now cover the board completely; you see it again when you resume (real-time games: when the 3-2-1 countdown starts).
- Long place names are shortened in the route line and the route records, so the destination stays visible; the tooltip shows the full name.
- Tavern Dice: "Victory!" from 150 points instead of 200.
- Goblin Minefield is now marked as a long game.
- The `/pastime` shortcuts that used other games' names are gone; use the game's own name (for example `/pastime rockfall`, `/pastime dice`). Your leaderboards, route records and statistics are kept.

## 1.0.0-beta2

Please report anything odd: https://github.com/Koslowsky1337/Pastime/issues

- Horde and Alliance: the window wears your faction's colours. Alliance characters get Gryphon Flight, Ram Dash and Bell Echo instead of Wind Rider, Kodo Dash and Totem Echo, Elwynn fish in Fishing and a meadow for the Wind Serpent.
- Fixed: on the game-over screen, the keyboard stayed locked when a fight started and "Hide in combat" was switched off.
- The version in the addon list and in `/pastime diag` now names the exact build.
- Zeppelins and boats: the window no longer reopens every ten minutes while you stand at a dock; a `/reload` during the ride no longer starts a phantom trip on arrival; falling off after departure, a hearthstone or dying no longer leaves wrong travel times or routes behind.
- Route records: a route can be deleted (the button asks once more before it does).
- English clients show 1,054,000 and ISO dates instead of the German 1.054.000 and 13.11.26.
- German client: Undercity, Thunder Bluff, Stormwind, Booty Bay, Ratchet and Southshore are named as the game names them. The Alliance test flight heads for Stormwind.
- Leaderboards: hover the list in the game details to see all ten places; the route records show all five places per game.
- Rune Pairs and Solitaire: the large display now counts moves and time while you play.
- Goblin Blackjack: the arrival dialog explains that the run is scored when it ends.
- Fishing: Enter opens the chat again instead of casting.
- Keys held with Ctrl or Alt no longer steer the game (Ctrl+S toggles the sound instead of turning the serpent).
- `/pastime` followed by one or two letters no longer starts a random game.
- Easier to read, also with red-green colour blindness: 2048 uses dark numbers on light tiles; Word Guess has a darker green and frames the correct letters; Gem Code and Gems use a teal crystal instead of the amethyst, which looked like the sapphire.
- Four in a Row: the opponent now makes mistakes, more often on the easier levels, and no longer answers the same moves the same way every time. Medium and Hard used to be nearly unbeatable.
- Goblin Blackjack: "Cash out" ends a run as a win once you are above 100 gold. Until now every run could only end broke.
- Card backs and rune backs are blue for the Alliance.
- A long destination name no longer sticks out of the arrival dialog; the route list shows the full name in a tooltip.

## 1.0.0-beta1 – first beta

All 19 games have been reviewed. Please report anything odd on GitHub.

**All games**
- Real-time games (Wind Serpent, Wind Rider, Kodo Dash, Kobold Bash, Rockfall, Wallbreaker, Murloc Invasion) show a 3-2-1 countdown when you resume after a pause, a landing or a fight.
- Score popups and messages are no longer hidden under the game board.
- The sidebar always shows how to pause.
- Your faction matters: Four in a Row, minefield flags, card and rune backs show Horde or Alliance.

**Games**
- Kodo Dash: new rock overhangs to slide under; the score is now shown as metres.
- Goblin Blackjack: your gold carries over between games and bets grow with it; going broke scores the highest gold of the run.
- Solitaire: drag cards with the mouse, a click sends a fitting card to its suit pile, fixed piles for each suit.
- Rockfall: a short lock delay lets you slide a landed block.
- Rune Pairs: clicking a third card covers a wrong pair at once.
- Smaller fixes for Fishing, Tavern Dice, Totem Echo, Wallbreaker and Word Guess.

## 1.0.0-alpha1 – test build

First automatic CurseForge build, mainly to test the packaging. The games are still being reviewed one by one.

- Wind Serpent: speeds up every 8 eggs instead of every egg; the sidebar shows the level. Fixed a gap in the body when the head follows the tail closely.
- Wind Serpent and Wind Rider: 3-2-1 countdown after a pause, so you don't crash right away.
- After game over, Space restarts only after 1.5 seconds (the button works at once).
- Game details and route records: the parchment now fills the whole panel; the route line uses the full width.
