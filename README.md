# Worm Run (Godot 4) - room codes, works online

Players: start the game, sign up / log in, then Create a room (you get a
4-letter code) or type a friend's code and Join.

## One-time server setup (Render)
1. Put this whole folder in a GitHub repo.
2. render.com -> New -> Web Service -> pick the repo.
   Language: Docker. Instance type: Free. Click Deploy.
3. Copy your address, like https://worm-run-server.onrender.com
4. Open main.gd and change the line near the top:
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
