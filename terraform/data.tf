data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "hcp_vault_secrets_secret" "oci_private_key" {
  app_name    = var.vault_app_name
  secret_name = var.oci_private_key_secret_name
}

data "hcp_vault_secrets_secret" "ssh_private_key" {
  app_name    = var.vault_app_name
  secret_name = var.ssh_private_key_secret_name
}

data "hcp_vault_secrets_secret" "ssh_public_key" {
  app_name    = var.vault_app_name
  secret_name = var.ssh_public_key_secret_name
}

data "hcp_vault_secrets_secret" "k3s_token" {
  app_name    = var.vault_app_name
  secret_name = var.k3s_token
}

data "hcp_vault_secrets_secret" "cf_token" {
  app_name    = var.vault_app_name
  secret_name = "cf_token"
}

data "hcp_vault_secrets_secret" "cf_account_id" {
  app_name    = var.vault_app_name
  secret_name = "cf_account_id"
}

data "hcp_vault_secrets_secret" "cf_zone_id" {
  app_name    = var.vault_app_name
  secret_name = "cf_zone_id"
}

data "hcp_vault_secrets_secret" "cf_origin_certificate" {
  app_name    = var.vault_app_name
  secret_name = "cf_origin_certificate"
}

data "hcp_vault_secrets_secret" "cf_private_key" {
  app_name    = var.vault_app_name
  secret_name = "cf_private_key"
}

data "hcp_vault_secrets_secret" "ca_certificate" {
  app_name    = var.vault_app_name
  secret_name = "cf_ca_certificate"
}

data "hcp_vault_secrets_secret" "mysql_database" {
  app_name    = var.vault_app_name
  secret_name = "mysql_database"
}

data "hcp_vault_secrets_secret" "mysql_port" {
  app_name    = var.vault_app_name
  secret_name = "mysql_port"
}

data "hcp_vault_secrets_secret" "mysql_password" {
  app_name    = var.vault_app_name
  secret_name = "mysql_password"
}

data "hcp_vault_secrets_secret" "mysql_root_password" {
  app_name    = var.vault_app_name
  secret_name = "mysql_root_password"
}

data "hcp_vault_secrets_secret" "mysql_user" {
  app_name    = var.vault_app_name
  secret_name = "mysql_user"
}

data "hcp_vault_secrets_secret" "authentik_secret_key" {
  app_name    = var.vault_app_name
  secret_name = "authentik_secret_key"
}

data "hcp_vault_secrets_secret" "authentik_bootstrap_password" {
  app_name    = var.vault_app_name
  secret_name = "authentik_bootstrap_password"
}

data "hcp_vault_secrets_secret" "authentik_postgresql_password" {
  app_name    = var.vault_app_name
  secret_name = "authentik_postgresql_password"
}

data "hcp_vault_secrets_secret" "authentik_redis_password" {
  app_name    = var.vault_app_name
  secret_name = "authentik_redis_password"
}

data "hcp_vault_secrets_secret" "authentik_bootstrap_token" {
  app_name    = var.vault_app_name
  secret_name = "authentik_bootstrap_token"
}

data "oci_core_vnic_attachments" "k3s_control_plane_vnic_attachment" {
  for_each       = { for idx, id in module.control_plane.control_plane_instance_ids : idx => id }
  compartment_id = var.compartment_ocid
  instance_id    = each.value
}

data "oci_core_vnic" "k3s_control_plane_vnic" {
  for_each = data.oci_core_vnic_attachments.k3s_control_plane_vnic_attachment
  vnic_id  = each.value.vnic_attachments[0].vnic_id
}

# Convert the list of instance IDs for x86 workers to a map for use with for_each
data "oci_core_vnic_attachments" "k3s_worker_x86_vnic_attachments" {
  for_each       = { for idx, id in module.workers_x86.worker_x86_instance_ids : idx => id }
  compartment_id = var.compartment_ocid
  instance_id    = each.value
}

data "oci_core_vnic" "k3s_worker_x86_vnics" {
  for_each = data.oci_core_vnic_attachments.k3s_worker_x86_vnic_attachments
  vnic_id  = each.value.vnic_attachments[0].vnic_id
}

# The ARM worker data blocks, assuming you haven't made any changes to those
data "oci_core_vnic_attachments" "k3s_worker_arm_vnic_attachments" {
  for_each       = { for idx, id in module.workers_arm.worker_arm_instance_ids : idx => id }
  compartment_id = var.compartment_ocid
  instance_id    = each.value
}

data "oci_core_vnic" "k3s_worker_arm_vnics" {
  for_each = data.oci_core_vnic_attachments.k3s_worker_arm_vnic_attachments
  vnic_id  = each.value.vnic_attachments[0].vnic_id
}

locals {
  # Public IPs
  k3s_control_plane_ips = [for vnic in data.oci_core_vnic.k3s_control_plane_vnic : vnic.public_ip_address]
  k3s_worker_arm_ips    = [for vnic in data.oci_core_vnic.k3s_worker_arm_vnics : vnic.public_ip_address]
  k3s_worker_x86_ips    = [for vnic in data.oci_core_vnic.k3s_worker_x86_vnics : vnic.public_ip_address]

  # Private IPs
  k3s_control_plane_private_ips = [for vnic in data.oci_core_vnic.k3s_control_plane_vnic : vnic.private_ip_address]
  k3s_worker_arm_private_ips    = [for vnic in data.oci_core_vnic.k3s_worker_arm_vnics : vnic.private_ip_address]
  k3s_worker_x86_private_ips    = [for vnic in data.oci_core_vnic.k3s_worker_x86_vnics : vnic.private_ip_address]

  worker_node_private_ip_map = merge(
    { for idx, ip in local.k3s_worker_arm_private_ips : format("worker_arm-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_x86_private_ips : format("worker_x86-%d", idx) => ip }
  )

  # All public instance IPs as a flat map (key-value pairs where value is a string)
  all_instance_ips_map = merge(
    { for idx, ip in local.k3s_control_plane_ips : format("control_plane-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_arm_ips : format("worker_arm-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_x86_ips : format("worker_x86-%d", idx) => ip }
  )

  # All private instance IPs as a flat map (key-value pairs where value is a string)
  all_private_instance_ips_map = merge(
    { for idx, ip in local.k3s_control_plane_private_ips : format("control_plane-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_arm_private_ips : format("worker_arm-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_x86_private_ips : format("worker_x86-%d", idx) => ip }
  )
}
