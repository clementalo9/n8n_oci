variable "tenancy_ocid" {
  description = "OCID of the Oracle Cloud Tenancy."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to be authorized on the instance."
  type        = string
}

variable "availability_domain" {
  description = "Availability Domain name (e.g., xx:US-ASHBURN-AD-1). Leave empty to auto-pick the first AD."
  type        = string
  default     = ""
}

# Compute shape (e.g., VM.Standard.A1.Flex for ARM or VM.Standard.E2.1.Micro for x86)
variable "shape" {
  type        = string
  description = "Compute shape. Use a Flex shape to customize OCPUs/RAM, or a fixed shape (like E2.1.Micro)."
  default     = "VM.Standard.A1.Flex"
}

# Flex-only: number of OCPUs
variable "ocpus" {
  type        = number
  description = "Number of OCPUs (Flex shapes only)."
  default     = 1
}

# Flex-only: memory in GB
variable "memory_in_gbs" {
  type        = number
  description = "Amount of memory in GB (Flex shapes only)."
  default     = 6
}
