variable "tenancy_ocid" {
  description = "OCID of Oracle Cloud Tenancy"
  type        = string
}

variable "ssh_public_key" {
  description = "SSh public key in OpenSSH format"
  type        = string
}

variable "user_ocid" {
  description = "OCID of Oracle Cloud User"
  type        = string
}

variable "fingerprint" {
  description = "Public key fingerprint"
  type        = string
}

variable "region" {
  description = "Region of Oracle Cloud"
  type        = string
}

variable "private_key_path" {
  description = "Private Key Path in .pem format"
  type        = string
}
