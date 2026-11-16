# Changelog

## 2.0.0-beta4

- New button “What wins?” in the card and gold games. Tavern Hold'em and Goblin Poker list the poker hands from strongest to weakest, each with an example hand and a short explanation; Goblin Blackjack shows example hands too; Goblin Blackjack, Higher or Lower and Goblin Roulette explain what wins and what it pays; Goblin Slots show their pay table there.
- The rules window now starts with the controls and explains the game below, for all 24 games in more detail than before: the goal, how a turn works, what scores and when the game ends.
- Solitaire: a tip (button or H) highlights a move that helps and says why. If no move is left, the game recognises it and ends as lost instead of leaving you searching.

## 2.0.0-beta3

Multiplayer, third test version: fixes from the first test with two players.

- A rematch request now arrives. After a game the other player's finished board kept them “busy”, so the request was dropped and the asker waited forever.
- The first time multiplayer is on, a window asks who may see you: friends, group, guild. Until you have answered, nothing is announced. The guild is now part of the suggestion; before, two guild members only saw each other if both had found the switch.
- Ending a session now reaches the other side: withdrawing a request removes its window, a request to someone who is busy is turned down at once, and a message for a session the other side does not have ends it instead of leaving one player waiting.
- If both players ask each other at the same moment, one of the two requests wins automatically instead of both waiting.
- Four in a Row: the colours are the same on both screens. The player who invited plays red, the invited player blue, and the board says which one you are.
- Friends: if the friend list only knows a first name, the full name is looked up in the guild list, because direct messages need it.
- For testing: `/pastime debug dump` shows what the game reports about your group, guild, friends and Battle.net friends, with all text masked; `/pastime debug dump klar` shows it in plain text.
- The log no longer fills up with messages of other addons, so `/pastime report` shows the course of a multiplayer test.

## 2.0.0-beta2

Multiplayer, second test version. Still switched off until both players type `/pastime mp`.

- The player list now follows who is really online: it asks the game's own group, guild and friend lists instead of remembering players for a quarter of an hour. Someone who logs out or leaves the group disappears at once.
- Friends are a third circle. Friends who are online and have Pastime with multiplayer appear in the list; there is a new switch “Visible to your friends”.
- After each name a coloured tag shows where you know the player from: (F) friend, (P) party, (G) guild. Friend comes before party, party before guild.
- Switching multiplayer off or hiding from a circle tells the others once, so you no longer show up as available.
- For testing: `/pastime debug user First Last` asks a player for a game directly, even if they are not in the list. `/pastime report` then contains the course of the session, with player ids instead of names.
- `/pastime debug test` asks whether to run quickly or with all sounds; closing its window cancels it.

## 2.0.0-beta1

Multiplayer, first test version. It is switched off until both players type `/pastime mp`.

- New tab “Multiplayer”: it lists players in your group (and, if you switch it on, your guild) who have Pastime with multiplayer on, with your record against them.
- Ask a player for a game. They get a small window to accept or decline; then you choose the game.
- First game: Four in a Row against another player. Only legal moves go through. The first game starts at random, in a rematch the loser begins.
- Closing the board, reloading or ten idle minutes pause a game without counting it. Ask the same player again within ten minutes to continue where you stopped. Giving up counts as a loss.
- A single-player game that is running when you accept waits and comes back afterwards.
- Settings: multiplayer on or off, and whether your group and your guild see you.
- Everything travels as invisible addon messages; nothing appears in chat.

## 1.3.0

- New: a “Settings” tab at the bottom of the window with the same switches as the addon options, each with its explanation, plus the bug report button.
- New: `/pastime debug test` runs a self-test in the game (client functions, sounds, textures, addon messages). A window shows what is being tested and all symbol pictures; the result opens to copy. It also asks other Pastime users in your guild and group for an invisible reply, to check that direct messages arrive before multiplayer needs them.
- Goblin Slots: more sayings under the result.
- New: update notice. Pastime quietly tells your guild and group which version you run (nothing else is sent, and nothing shows up in chat). If someone there has a newer release, you get one line in chat telling you to update.
- Gold games: every run now starts with 1,000 gold instead of 100, and the jackpot starts at 10,000. Running purses and old records get the extra 900 gold once, so they stay comparable.
- Goblin Slots: more small wins. From the murloc upwards two of a kind already pay a little, and three fish or bombs pay less than before. A good half of all spins now return something; small wins show honestly how much of your bet came back.
- Goblin Slots, free spins reworked. The rune is now the wild symbol (the coin no longer is) and still the scatter: at most one per reel, three runes pay 2 times your bet and give 10 free spins, four pay 10 times and give 20.
- Goblin Slots: when free spins hit you hear a fanfare and nothing spins on its own. You press Space to spin the middle reel for your bonus symbol, see it on its own, and then each Space plays one free spin (or switch on auto-spin for them).
- Goblin Slots: whenever the bonus symbol lands on three or more reels in a free spin, those reels fill up with it field by field and pay for that many of a kind, gaps or not. Five reels fill the whole screen. Runes during free spins extend them and let you draw a second bonus symbol; both then pay.
- Goblin Slots: big wins count up instead of just appearing. The pay table moved into the rules (button on the right) and is shown as multiples of your bet; below the reels you only see what the rune does and that it is the wild symbol that joins a line together. Line pays were adjusted; the payout rate stays at about 96 %.

## 1.2.0

- Goblin Slots, Goblin Blackjack, Goblin Poker and Higher or Lower: you now set your bet once (10, 25, 50, 100, 250 … up to your gold) with 1 and 2 or the – and + buttons, 3 picks the highest, and Space plays. The bet stays for the next round and is remembered.
- Goblin Slots: auto-spin. Press A or the button and the machine plays 20 spins at your bet. It stops early when free spins hit, when you switch it off or when you run out of gold.
- Goblin Slots: three, four or five runes now also pay 1, 5 or 20 times your bet on the spot. The line pays were lowered slightly; the payout rate stays at about 96 %.
- Goblin Roulette: the spin button offers “Repeat bets” when the table is empty, and your last bets survive closing the window.
- Tavern Hold'em: closing the window in the middle of a hand keeps the hand exactly as it was; it continues when you come back.
- New: a jackpot shared by all six gold games. A tenth of every loss goes into the pot, and each game has one rare event that wins it (hover over the jackpot to see which): five rubies or coins on a line in Goblin Slots, the ace and jack of spades in Goblin Blackjack, a straight flush or four jacks or better in Goblin Poker, a pot of 1,000 times your bet in Higher or Lower, two hits in a row on a single number in Goblin Roulette, and a pot won with four of a kind or better in Tavern Hold'em.
- New: daily task. Every day one game with a goal, shown at the bottom of the game list; a click starts it. Finishing it on consecutive days builds a streak.
- Gold games: a run that never got above the 100 gold you start with is no longer entered in the records, and such old entries are removed.

## 1.1.0

- Goblin Slots: new rune symbol. Three, four or five runes anywhere on the reels give 5, 8 or 12 free spins at the same bet; free spins can win more free spins and survive closing the window. The pay table was lowered slightly to make room for them.
- Goblin Slots: coins at the start of a line now count the better way. Four coins and a fish paid as five fish (12) instead of four coins (40).
- Goblin Roulette: a wheel with all 37 pockets. The ball runs around it, slows down and comes to rest in the winning pocket; it stays there until the next spin. The last 15 numbers are listed to the left of the table, newest on top.
- Bug reports: `/pastime report` (or the new button in the options) opens a report to copy into a GitHub issue. It contains the recent log including the detailed lines of the last minutes, without needing debug mode first, and character names are replaced.
- Client functions that fail are no longer skipped silently: the first failure of each is written to the log as a warning and the report counts them.
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
