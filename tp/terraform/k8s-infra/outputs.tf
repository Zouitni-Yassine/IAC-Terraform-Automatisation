output "k3s_server_public_ip" {
  value = oci_core_instance.k3s_server.public_ip
}

output "k3s_server_private_ip" {
  value = oci_core_instance.k3s_server.private_ip
}

output "k3s_agents_public_ips" {
  value = [for inst in oci_core_instance.k3s_agents : inst.public_ip]
}

output "kubeconfig_fetch_command" {
  description = "Run this from your machine to fetch the kubeconfig"
  value       = "ssh ubuntu@${oci_core_instance.k3s_server.public_ip} sudo cat /etc/rancher/k3s/k3s.yaml | sed 's|127.0.0.1|${oci_core_instance.k3s_server.public_ip}|' > kubeconfig"
}

output "hosts_entries" {
  description = "Add to your hosts file"
  value       = "${oci_core_instance.k3s_server.public_ip} prod-k8s.gestion-produits.local dev-k8s.gestion-produits.local"
}
