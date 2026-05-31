variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID"
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI API private key (.pem)"
  type        = string
}

variable "region" {
  description = "OCI region (your home region — France = eu-paris-1 or eu-marseille-1)"
  type        = string
  default     = "eu-paris-1"
}

variable "compartment_ocid" {
  description = "Target compartment OCID (root tenancy if blank)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to inject into the VM"
  type        = string
}

variable "git_repo_url" {
  description = "Public Git repo URL containing the tp/ folder"
  type        = string
  default     = "https://github.com/Zouitni-Yassine/IAC-Terraform-Automatisation.git"
}

variable "availability_domain" {
  description = "OCI availability domain (e.g. xxxx:EU-FRANKFURT-1-AD-1)"
  type        = string
  default     = ""
}
