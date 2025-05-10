return {
  importance = 100,
  title = "Zyla's Dilemma",
  description = "Help Zyla with her dress!",
  npc = "zyla", -- Who to talk to to activate the dialogue; isn't needed if repeatCheck is active
  unlock = {
    "quest_3",
  },
  repeatCheck = false, -- not implemented in the end
  dialogue = {
    { "freeze", "player" },
    { "addItem", { -- starting items
      { name = "Childish Fabric", tags = { "fabric", "silly", "texture.silly_1" }, },
      { name = "Neutral Fabric", tags = { "fabric", "neutral", "texture.neutral_1" }, },
      { name = "Fancy Fabric", tags = { "fabric", "fancy", "texture.fancy_1" }, },
      -- { name = "n", tags = { "fabric", "texture.neutral_2" }, }, --- Taken
      -- { name = "n", tags = { "fabric", "texture.heirloom_1" }, }, ---
      -- { name = "n", tags = { "fabric", "texture.heirloom_2" }, }, ---
      -- { name = "n", tags = { "fabric", "texture.neutral_3" }, }, --- lyn bark
      -- { name = "n", tags = { "fabric", "texture.neutral_4" }, }, ---
    } },
    { "setState", "state_intro"},
    { "tag", "state_intro" },
    { "setQuestNPC", "zyla" },
    { "setObjective", "Listen to Zyla's request" },
    { "teleportToDoor", "zyla", "town-workshop", "town" },
    { "useDoor", "zyla", "town-workshop" },
    { "moveX", "zyla", -2 },
    { "setCharacter", "zyla" },
    "Good morning, I am here to see Rosetta. Is she around? I need my [b][rainbow]fancy[/rainbow][/b] dress repaired.",
    { "setCharacter", "player" },
    "Rosetta is not here this morning. I am here to take care of all sewing and mending and would love to help!",
    { "setCharacter", "zyla" },
    "Oh, but Rosetta is the one who made this garment for me, I have been wearing it to my council meetings.",
    { "choice", {
      { "and she did a fine job! Please let me have a look.", "option_one" },
      { "I have just the thing for it!", "option_one" }
    } },
    { "tag", "option_one" },
    { "addItem", {
      {
        name = "Zyla's Dress",
        id = "zyla_dress",
        tags = { "clothing", "dress", "fabric.fancy", "issue.patch", "patch.zyla_dress" },
      },
    } },
    { "setCharacter", nil },
    "[b][bounce=7]Added Item to Inventory[/bounce][/b][newline][newline]Zyla's Dress",
    { "unfreeze", "player" },
    { "setState", "patch_time" },
    { "setObjective", "Patch Zyla's Dress" },
    -- { "highlight", "interact.patch" }, -- todo highlight patch machine
    { "end" },
    { "tag", "patch_time" },
    { "freeze", "player" },
    { "if", "item", "zyla_dress", "hasTag", "patch.silly", "silly_design" }, -- So the patching minigame would add the "patched.<patchType>" tag to the dress
    { "if", "item", "zyla_dress", "hasTag", "patch.neutral", "neutral_design" },
    { "if", "item", "zyla_dress", "hasTag", "patch.fancy", "fancy_design" },
    -- { "tag", "not_finished" },
    { "setCharacter", "zyla" },
    "Have you finished my dress?",
    { "unfreeze", "player" },
    { "end" },
    { "tag", "silly_design" },
    { "setCharacter", "zyla" },
    "How dare you ruin my [b][rainbow]fancy[/rainbow][/b] dress with that silly patch! Rosetta will hear about this!",
    { "goto", "end_option_one" },
    { "tag", "neutral_design" },
    { "setCharacter", "zyla" },
    "This will do, thank you for your service, young man.",
    { "goto", "end_option_one" },
    { "tag", "fancy_design" },
    { "setCharacter", "zyla" },
    "Well, this is quite stylish, you know, I do have a few heirloom fabrics just sitting around my place, I think you might be the person to make good use of them. Can't wait to see what you will make.",
    { "addItem", {
      { name = "Zyla's Heirloom fabric", tags = { "fabric", "heirloom", "texture.heirloom_1", }, },
      { name = "Zyla's Heirloom fabric", tags = { "fabric", "heirloom", "texture.heirloom_2", }, },
    } },
    { "setCharacter", nil },
    "[b][bounce=7]Added Item to Inventory[/bounce][/b][newline][newline]Zyla's Heirloom fabric x2",
    { "goto", "end_option_one" },
    { "tag", "end_option_one" },
    { "removeItem", {
      "zyla_dress",
    }},
    { "questFinished" },
    { "if", "item", "RRE_material", "hasTag", "fabric", "skipLyn" },
    { "if", "item", "RRE_material_2", "hasTag", "fabric", "skipLyn" },
    { "setCharacter", "zyla" },
    "I understand Lyn received new materials last night. You ought to speak with her.",
    { "tag", "skipLyn" },
    { "unfreeze", "player" },
    { "moveX", "zyla", 2 },
    { "useDoor", "zyla", "town-workshop" },
    { "goHome", "zyla" }, -- teleport back to home location
    { "end" },
  }
}
