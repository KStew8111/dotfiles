return {
  {
    "EdenEast/nightfox.nvim",
    config = function()
      require("nightfox").setup {
        options = {
          transparent = true,
          styles = {
            comments = "italic",
            conditionals = "italic",
            keywords = "italic,bold",
            types = "italic,bold",
            operators = "bold",
            variables = "bold",
          },
        },
      }
    end,
  },
}
