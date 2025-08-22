provider "oci" {}

# Resolve tenancy/compartment
data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

locals {
  # Compartment to deploy into (root by default)
  compartment_ocid = data.oci_identity_tenancy.this.id
}

# List availability domains to optionally auto-pick one
data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_ocid
}

locals {
  # If availability_domain is empty, use the first AD available
  ad_name     = var.availability_domain != "" ? var.availability_domain : data.oci_identity_availability_domains.ads.availability_domains[0].name
  # Flex shapes list to decide when to send shape_config
  flex_shapes = ["VM.Standard.A1.Flex", "VM.Standard.E4.Flex", "VM.Standard.E3.Flex"]
}

# Pick an Ubuntu image compatible with the selected shape (ARM vs x86)
data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# --- Networking ---

resource "oci_core_virtual_network" "n8n_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = local.compartment_ocid
  display_name   = "n8n-vcn"
  dns_label      = "n8nvcn"
}

resource "oci_core_security_list" "n8n_security" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_virtual_network.n8n_vcn.id
  display_name   = "n8n-security"

  # Allow all outbound traffic
  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }

  # SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options { min = 22, max = 22 }
  }

  # HTTP
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options { min = 80, max = 80 }
  }

  # HTTPS
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options { min = 443, max = 443 }
  }

  # n8n UI
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options { min = 5678, max = 5678 }
  }
}

resource "oci_core_internet_gateway" "n8n_igw" {
  compartment_id = local.compartment_ocid
  display_name   = "n8n-igw"
  vcn_id         = oci_core_virtual_network.n8n_vcn.id
}

resource "oci_core_route_table" "n8n_route_table" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_virtual_network.n8n_vcn.id
  display_name   = "n8n-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.n8n_igw.id
  }
}

resource "oci_core_subnet" "n8n_subnet" {
  cidr_block                 = "10.0.1.0/24"
  compartment_id             = local.compartment_ocid
  vcn_id                     = oci_core_virtual_network.n8n_vcn.id
  display_name               = "n8n-subnet"
  route_table_id             = oci_core_route_table.n8n_route_table.id
  security_list_ids          = [oci_core_security_list.n8n_security.id]
  dns_label                  = "n8nsubnet"
  prohibit_public_ip_on_vnic = false
}

# --- Compute ---

resource "oci_core_instance" "n8n_instance" {
  # Set the requested shape; shape_config will be added only for Flex shapes
  shape               = var.shape
  availability_domain = local.ad_name
  compartment_id      = local.compartment_ocid
  display_name        = "n8n-instance"

  # Attach shape_config only when using a Flex shape (prevents invalid ratio errors on fixed shapes)
  dynamic "shape_config" {
    for_each = contains(local.flex_shapes, var.shape) ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.n8n_subnet.id
    assign_public_ip = true
  }

  metadata = {
    # Authorize the provided SSH public key on the instance
    ssh_authorized_keys = var.ssh_public_key
    # Cloud-init user data: installs Docker and runs n8n (script path is relative to repo)
    user_data           = filebase64("${path.module}/../scripts/install_n8n.sh")
  }
}

# Public IP of the created instance (useful for quick access to http://<IP>:5678)
output "n8n_public_ip" {
  value = oci_core_instance.n8n_instance.public_ip
}
