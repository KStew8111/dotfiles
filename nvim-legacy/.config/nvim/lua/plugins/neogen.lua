return {
  "danymat/neogen",
  config = true,
  -- Uncomment next line if you want to follow only stable versions
  -- version = "*"
  keys = {
    { "<Leader>nf", function() require("neogen").generate() end, desc = "Generate annotation (Neogen)" },
  },
}
