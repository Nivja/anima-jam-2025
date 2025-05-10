return {
  importance = -1,
  npc = "lyn",
  noShow = true,
  repeatCheck = false,
  dialogue = {
    { "setState", "entry" },
    { "tag", "entry" },
    { "freeze", "player" },
    { "setCharacter", "lyn" },
    "Hey! How's my favourite artisan doing? Do you need more materials from the RRE?",
    { "tag", "choice" },
    { "choice", {
      { "Yes! Have you got any for me?", "material" },
      { "What is the RRE?", "RRE_what" },
      -- { "I'm doing well!", "hi" }, -- could be exit?
    } },
    { "tag", "material" },
    { "if", "item", "RRE_material", "hasTag", "fabric", "order" }, -- already gained material from Lyn
    { "setCharacter", "lyn" },
    "Here you go! I got these in on last night's train. Let me know if you need more and I'll order it in.",
    { "addItem", {
      { name = "RRE Material", id = "RRE_material", tags = { "fabric", "neutral", "texture.neutral_3" }, },
    } },
    { "setCharacter", nil },
    "[b][bounce=5]Added Item to Inventory[/bounce][/b][newline][newline]RRE Material",
    { "unfreeze", "player" },
    { "end" },
    { "tag", "order" },
    { "setCharacter", "lyn" },
    "I'll put an order in, and see what we can get in!",
    { "unfreeze", "player" },
    { "end" },
    { "tag", "RRE_what" },
    { "setCharacter", "lyn" },
    "Did the solar flares get to you? The Regional Resource Exchange is just our way of keeping good stuff circulating across the region.",
    "We handle the logistics, reusing our current transit networks, like the trains, for efficient transport, prioritizing routes and minimizing unnecessary fuel consumption.",
    "Essentially, it's where communities share extra bits and pieces, second-hand treasures and even some new eco-friendly materials.",
    { "setCharacter", "player" },
    "Thanks for reminding me Lyn!",
    { "setCharacter", "lyn" },
    "No problem, I'll be seeing you around town. Perhaps you should make some sun hats.",
    { "unfreeze", "player" },
    { "end" },
    -- { "goto", "choice" }, -- make it loop back to selection?
  }
}
