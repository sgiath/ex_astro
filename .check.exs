[
  tools: [
    {:credo, "mix credo --strict"},
    {:markdown,
     command: "prettier \"**/*.{md,livemd}\" --check --log-level warn",
     fix: "prettier \"**/*.{md,livemd}\" --write --log-level warn"}
  ]
]
