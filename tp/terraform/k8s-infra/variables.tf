variable "tenancy_ocid" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "region" {
  description = "OCI region (your home region — France = eu-paris-1 or eu-marseille-1)"
  type        = string
  default     = "eu-paris-1"
}

variable "compartment_ocid" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "agent_count" {
  description = "Number of k3s agent nodes (workers)"
  type        = number
  default     = 2
}

variable "availability_domain" {
  type    = string
  default = ""
}
