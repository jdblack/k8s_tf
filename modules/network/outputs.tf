# Spend these on a listener's parentRef. Coming from the Gateway object rather than the variable that
# named it, they carry the ordering edge that puts listeners after the Gateway and its CRDs, without
# dragging the whole network module into the dependency set of everything else the caller owns.
output "gateway_name" {
  value = module.gateway["private"].name
}

output "gateway_namespace" {
  value = module.gateway["private"].namespace
}