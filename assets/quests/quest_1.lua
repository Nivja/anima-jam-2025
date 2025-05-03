return {
  title = "Zyla's Dilemma",
  description = "Help Zyla with her dress!",
  npc = "zyla", -- Who to talk to to activate the dialogue; isn't needed if repeatCheck is active
  unlock = {
    "quest_2",
  },
  repeatCheck = false,
  dialogue = {
    { "freeze", "player" },
    { "setState", "state_intro"},
    { "tag", "state_intro" },
    { "setQuestNPC", "zyla" },
    { "setObjective", "Listen to Zyla's request" },
    { "teleportToDoor", "zyla", "town-workshop", "town" },
    { "useDoor", "zyla", "town-workshop" },
    { "moveX", "zyla", -2 },
    { "setCharacter", "zyla" },
    "Good morning, I am here to see Rosetta. Is she around? I need my dress repaired.",
    { "setCharacter", "player" },
    "Rosetta is not here this morning. I am here to help with all sewing and mending and would love to help!",
    { "setCharacter", "zyla" },
    "Oh, but Rosetta is the one who made this garment for me, I have been wearing it to my council meetings.",
    { "choice", {
      { "and she did a fine job! Please let me have a look.", "option_one" },
      { "I have just the thing for it!", "option_one" }
    } },
    { "tag", "option_one" },
    { "setObjective", "Find fabric to use" },
    { "addItem", {
    -- Add items to be found
      -- { name = "Childish Fabric", tags = { "fabric", "use-patch" }, patchType = "silly", },
      -- { name = "Neutral Fabric", tags = { "fabric", "use-patch" }, patchType = "neutral", },
      -- { name = "Fancy Fabric", tags = { "fabric", "use-patch" }, patchType = "fancy", },
      { -- todo
        name = "Zyla's Dress",
        id = "zyla_dress",
        issue = { {
          --[[ issue details for minigame... ]]
        } },
        tags = { "clothing", "dress", "fancy" },
        --[[ item details... ]]
      },
    } },
    { "unfreeze", "player" },
    -- todo check if items are in player's inventory; then allow to continue
    { "setState", "patch_time" },
    { "end" },
    { "tag", "patch_time" },
    { "setObjective", "Patch Zyla's Dress" },
    
    -- { "setState", "state_option_one"}, -- State is persistent if the conversation ends; it will return to the tagged point
    -- { "inspectItem", "lastAdded" }, -- Makes item pop up on user's screen - might be scoped out
    -- { "minigame", "patch", "zyla_dress" }, -- 3rd arg is optionally, skip inventory screen to given item  (lastAdded being a keyword)
    { "tag", "state_option_one" },
    { "if", "item", "zyla_dress", "hasTag", "patched.silly", "silly_design" }, -- So the patching minigame would add the "patched.<patchType>" tag to the dress
    { "if", "item", "zyla_dress", "hasTag", "patched.neutral", "neutral_design" },
    { "if", "item", "zyla_dress", "hasTag", "patched.fancy", "fancy_design" },
    { "tag", "not_finished" },
    { "setCharacter", "zyla" }, -- Shouldn't reach this point, i.e. if the dress has none of those above tags; but we handle it by ending the conversion
    "Have you finished my dress?",
    { "end" },
    { "tag", "silly_design" },
    { "setCharacter", "zyla" },
    "Rosetta will hear about this!",
    { "goto", "end_option_one" },
    { "tag", "neutral_design" },
    { "setCharacter", "zyla" },
    "This will do, thank you for your service, young man",
    { "goto", "end_option_one" },
    { "tag", "fancy_design" },
    { "setCharacter", "zyla" },
    "Well, this is quite stylish, you know, I do have a few heirloom fabrics just sitting around my place, I think you might be the person to make good use of them. Can't wait to see what you will make.",
    { "addItem",
      { name = "Old Lady's Heirloom fabric 1" },
      { name = "Old Lady's Heirloom fabric 2" },
    },
    { "goto", "end_option_one" },
    { "tag", "end_option_one" },
    { "questFinished" },
    { "end" },
  }
}