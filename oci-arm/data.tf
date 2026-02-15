data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_compartment_id
}

data "oci_core_images" "ampere-ubuntu-images" {
  compartment_id           = var.oci_compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
