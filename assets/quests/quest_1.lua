return {
  title = "Zyla's Dilemma",
  npc = "zyla", -- Who to talk to to activate the dialogue
  unlock = {
    "quest_2",
  },
  dialogue = {
    { "setState", "state_intro"},
    { "setObjective", "Listen to Zyla's request" }
    { "tag", "state_intro" },
    { "teleportToDoor", "zyla", "town-workshop", "town" },
    { "useDoor", "zyla", "town-workshop" },
    { "moveX", "zyla", -5 }, -- move towards table
    { "setCharacter", "zyla" },
    "Good morning, I am here to see Rosetta. Is she around? I need my dress fixed.",
    { "setCharacter", "player" },
    "Rosetta is not here this morning. I am here to help with all sewing and mending and would love to help",
    { "setCharacter", "zyla" },
    "Oh, but Rosetta is the one who made this garment for me, I have been wearing it to my council meetings.",
    { "choice",
      { "and she did a fine job! Please let me have a look. [color=#7DFFFF]{Tutorial}[/color]", --[[ goto ]] "option_one" },
      { "If you would rather wait, Rosetta will be here for the evening shift.", --[[ goto ]] "option_two" },
    },
    { "tag", "option_one" }, -- [[ Declare a point which can be 'goto'ed ]]
    { "setObjective", "Patch Zyla's Dress" },
    { "addItem",
    -- Add items required for the mini game
      { name = "Childish Fabric", tags = { "fabric", "use-patch" }, patchType = "silly", },
      { name = "Neutral Fabric", tags = { "fabric", "use-patch" }, patchType = "neutral", },
      { name = "Fancy Fabric", tags = { "fabric", "use-patch" }, patchType = "fancy", },
      {
        name = "Zyla's Dress",
        id = "zyla_dress",
        issue = { {
          --[[ issue details for minigame... ]]
        } },
        tags = { "clothing", "dress", "fancy" },
        --[[ item details... ]]
      },
    },
    { "setState", "state_option_one"}, -- State is persistent if the conversation ends; it will return to the tagged point
    -- { "inspectItem", "lastAdded" }, -- Makes item pop up on user's screen - might be scoped out
    { "minigame", "patch", "zyla_dress" }, -- 3rd arg is optionally, skip inventory screen to given item  (lastAdded being a keyword)
    { "tag", "state_option_one" },
    { "if", "item", "zyla_dress", "hasTag", "patched.silly", "silly_design" }, -- So the patching minigame would add the "patched.<patchType>" tag to the dress
    { "if", "item", "zyla_dress", "hasTag", "patched.neutral", "neutral_design" },
    { "if", "item", "zyla_dress", "hasTag", "patched.fancy", "fancy_design" },
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
    { "tag", "option_two" },
    { "setState", "option_two"},
    { "setCharacter", "zyla" },
    "I'll be back then",
    -- todo mini game
    { "questFinished" },
    { "end" },
  }
}