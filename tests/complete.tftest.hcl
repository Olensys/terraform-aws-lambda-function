# Run only by the nightly integration workflow, against real cloud credentials.
run "apply_minimal" {
  command = apply

  module {
    source = "./examples/minimal"
  }
}
