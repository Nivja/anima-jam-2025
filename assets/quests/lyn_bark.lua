return {
  importance = -1,
  npc = "lyn",
  noShow = true,
  repeatCheck = false,
  dialogue = {
    { "tag", "one" },
    { "freeze", "player" },
    { "setCharacter", "lyn" },

    { "setState", "two" },
    { "unfreeze", "player" },
    { "end" },
    { "tag", "two" },
    { "freeze", "player" },
    { "setCharacter", "lyn" },

    { "setState", "three" },
    { "unfreeze", "player" },
    { "end" },
    { "tag", "three" },
    { "freeze", "player" },
    { "setCharacter", "lyn" },

    { "setState", "four" },
    { "unfreeze", "player" },
    { "end" },
    { "tag", "four" },
    { "freeze", "player" },
    { "setCharacter", "lyn" },
    
    { "setState", "one" },
    { "unfreeze", "player" },
    { "end" },
  }
}
