[
  tools: [
    {:compiler, true},
    {:formatter, true},
    {:unused_deps, true},
    {:credo, true},
    {:markdown,
     command: "prettier \"**/*.{md,livemd}\" --log-level warn",
     fix: "prettier \"**/*.{md,livemd}\" --write --log-level warn"},
    {:ex_unit, true}
  ]
]
