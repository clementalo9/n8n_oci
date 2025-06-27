provider "oci" {}

data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

locals {
  compartment_ocid = data.oci_identity_tenancy.this.id
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
}

resource "oci_core_virtual_network" "n8n_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = local.compartment_ocid
  display_name   = "n8n-vcn"
  dns_label      = "n8nvcn"
}

# Security list allowing SSH, HTTP/HTTPS and n8n ports
resource "oci_core_security_list" "n8n_security" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_virtual_network.n8n_vcn.id
  display_name   = "n8n-security"

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 5678
      max = 5678
    }
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

resource "oci_core_instance" "n8n_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  compartment_id      = local.compartment_ocid
  display_name        = "n8n-instance"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    memory_in_gbs = 4
    ocpus         = 1
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
    ssh_authorized_keys = var.ssh_public_key
    user_data           = filebase64("${path.module}/../scripts/install_n8n.sh")
  }
}

output "n8n_public_ip" {
  value = oci_core_instance.n8n_instance.public_ip
}
