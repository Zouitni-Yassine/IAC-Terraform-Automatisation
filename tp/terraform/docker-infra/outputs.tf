output "docker_vm_public_ip" {
  description = "Public IP of the Docker VM"
  value       = oci_core_instance.docker_vm.public_ip
}

output "docker_vm_private_ip" {
  description = "Private IP of the Docker VM"
  value       = oci_core_instance.docker_vm.private_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh ubuntu@${oci_core_instance.docker_vm.public_ip}"
}

output "traefik_dashboard" {
  description = "Traefik dashboard URL"
  value       = "http://${oci_core_instance.docker_vm.public_ip}:8080"
}

output "hosts_entries" {
  description = "Lines to add to your /etc/hosts (or C:/Windows/System32/drivers/etc/hosts on Windows)"
  value       = "${oci_core_instance.docker_vm.public_ip} prod.gestion-produits.local dev.gestion-produits.local"
}
