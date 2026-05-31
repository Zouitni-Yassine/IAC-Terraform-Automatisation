data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  ad_name = var.availability_domain != "" ? var.availability_domain : data.oci_identity_availability_domains.ads.availability_domains[0].name
}

data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# ---------- Network ----------

resource "oci_core_vcn" "k8s_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "tp-k8s-vcn"
  cidr_blocks    = ["10.20.0.0/16"]
  dns_label      = "tpk8s"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "tp-k8s-igw"
  enabled        = true
}

resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "tp-k8s-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "public_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s_vcn.id
  display_name   = "tp-k8s-public-sl"

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # SSH
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTP/HTTPS for the Ingress
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Kubernetes API
  ingress_security_rules {
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # All internal traffic between cluster nodes
  ingress_security_rules {
    source      = "10.20.0.0/16"
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.k8s_vcn.id
  display_name               = "tp-k8s-public-subnet"
  cidr_block                 = "10.20.1.0/24"
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.public_sl.id]
  dns_label                  = "pubsub"
  prohibit_public_ip_on_vnic = false
}

# ---------- k3s server ----------

resource "oci_core_instance" "k3s_server" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name
  display_name        = "tp-k3s-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "k3s-server"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/k3s-server.yaml", {
      k3s_token = random_password.k3s_token.result
    }))
  }
}

# ---------- k3s agents ----------

resource "oci_core_instance" "k3s_agents" {
  count               = var.agent_count
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name
  display_name        = "tp-k3s-agent-${count.index + 1}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = true
    hostname_label   = "k3s-agent-${count.index + 1}"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/k3s-agent.yaml", {
      k3s_token  = random_password.k3s_token.result
      server_ip  = oci_core_instance.k3s_server.private_ip
    }))
  }

  depends_on = [oci_core_instance.k3s_server]
}
