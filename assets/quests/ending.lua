return {
  importance = 100,
  title = "Ending",
  description = "Thanks for playing",
  npc = nil, -- Who to talk to to activate the dialogue; isn't needed if repeatCheck is active
  unlock = { },
  dialogue = {
    { "freeze", "player" },
    { "ending" },
    { "setCharacter", "team" },
    "[bounce][rainbow]Thank you for playing![/rainbow][/bounce][newline]We hope you enjoyed [b]Textile Artisan[/b].",
    "This was a prototype game made for the Day Zero Games: Solarpunk Jam over the course of 19 days!",
    "We had a great time putting this prototype together. Thank you to everyone who put this Jam on from Zero Day, Anima Interactive and Cinereach!",
    "Brought to you by a team of 4 from across the globe.[newline][b]EngineerSmith[/b]: Lead Developer & Programmer[newline][b]Niva[/b]: Game Designer[newline][b]Daiika[/b]: Artist[newline][b]Matis[/b]: Composer",
    "[pause=1] Every thread counts. Together, let's weave a more vibrant world.",
    { "ending" },
    { "unfreeze", "player" },
    { "questFinished" },
    { "end" },
  }
}
