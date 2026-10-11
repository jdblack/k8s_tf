locals {
  # The connector pod runs on its own egress policy, so the baseline has to not also admit it.
  connector = "typingmind-mcp"
}
