# Worm Run (Godot 4) - room codes, works online

Players: start the game, sign up / log in, then Create a room (you get a
4-letter code) or type a friend's code and Join.

## One-time server setup (Render)
1. Put this whole folder in a GitHub repo.
2. render.com -> New -> Web Service -> pick the repo.
   Language: Docker. Instance type: Free. Click Deploy.
3. Copy your address, like https://worm-run-server.onrender.com
4. Open scripts/main.gd and change the line near the top:
   const SERVER_URL := "wss://worm-run-server.onrender.com"
   (https:// becomes wss://)
5. Run the game (F5) or export it and send it to your friends.

## Notes
- Free Render servers sleep after 15 minutes with no traffic and take about a
  minute to wake. The game retries by itself.
- Render's free disk is wiped when the server sleeps or redeploys, so
  accounts reset then. A paid plan with a persistent disk keeps them.
- Passwords are salted + hashed on the server; wss:// encrypts the connection.
- Test on your own computer: set SERVER_URL to "ws://127.0.0.1:10000", run
  `godot --headless --path . -- --server` in a terminal, then F5.

## Mobile
- Touch controls turn on automatically on phones and tablets (Settings ->
  Touch controls: Auto / On / Off). Left pad = move, right button = jump,
  tap or hold the world to break or place, the Break/Place button switches
  what a tap does, and the pause button is at the top centre.
- To try the touch layout on a computer: Settings -> Touch controls -> On, then
  use the mouse like a finger.
- Android: Project -> Export -> Android (needs the Android export template and
  SDK set up once). The Back button opens the pause menu.
- Browser on a phone: Project -> Export -> Web (Godot 4.3 or newer), upload the
  exported folder to any HTTPS host (itch.io, Netlify, GitHub Pages...).
  Rotate the phone to landscape.
- Settings (touch mode, zoom, remembered username) are saved on the device.

## Menus
Connect -> Log in / Sign up -> Main menu (Create room, Join room, How to play,
Settings, Log out). In a game, Esc (or the pause button) opens the pause menu
with Resume, Copy room code and Leave room.

