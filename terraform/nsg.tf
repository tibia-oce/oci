# ====================================================================
# Network Security Group (NSG) Definitions
# These resources define the NSGs for the public load balancer and 
# connections between the load balancer and the K3s compute instances.
# ====================================================================

resource "oci_core_network_security_group" "public_lb_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "Public Load Balancer NSG"
}

resource "oci_core_network_security_group" "lb_to_instances_http" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "Public LB to K3s Workers Compute Instances NSG"
}

resource "oci_core_network_security_group" "lb_to_instances_kubeapi" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "Public LB to K3s Master Compute Instances NSG (kubeapi)"
}

# ====================================================================
# Public Load Balancer NSG Rules
# These rules define the ingress traffic allowed to the public load 
# balancer, including HTTP, HTTPS, and KubeAPI from specific sources.
# ====================================================================

resource "oci_core_network_security_group_security_rule" "allow_http_from_all" {
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow HTTP from all"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.http_lb_port
      min = var.http_lb_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_https_from_all" {
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow HTTPS from all"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.https_lb_port
      min = var.https_lb_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_from_nodes" {
  for_each = local.all_private_instance_ips_map

  source                    = "${each.value}/32"
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  description               = "Allow KubeAPI ingress traffic from nodes on port 6443"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_from_my_ip" {
  count                     = var.expose_kubeapi ? 1 : 0
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow KubeAPI access from whitelisted IPs"

  source      = var.my_public_ip_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

# ====================================================================
# Load Balancer to Instances NSG Rules
# These rules define the ingress traffic allowed from the public load 
# balancer to the K3s compute instances for HTTP, HTTPS, and KubeAPI.
# ====================================================================

resource "oci_core_network_security_group_security_rule" "nsg_to_instances_http" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_http.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow HTTP traffic from Public LB NSG to K3s Workers"

  source      = oci_core_network_security_group.public_lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.http_lb_port
      min = var.http_lb_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_to_instances_https" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_http.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow HTTPS traffic from Public LB NSG to K3s Workers"

  source      = oci_core_network_security_group.public_lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.https_lb_port
      min = var.https_lb_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_to_instances_kubeapi" {
  count                     = var.expose_kubeapi ? 1 : 0
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow KubeAPI traffic from Public LB NSG to K3s Master"

  source      = oci_core_network_security_group.public_lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_from_lb" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP
  description               = "Allow KubeAPI traffic from the Load Balancer to K3s Master"
  source                    = oci_core_network_security_group.public_lb_nsg.id
  source_type               = "NETWORK_SECURITY_GROUP"
  stateless                 = false

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_to_lb" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  direction                 = "EGRESS"
  protocol                  = 6 # TCP
  description               = "Allow traffic from K3s Master to Load Balancer"
  destination               = oci_core_network_security_group.public_lb_nsg.id
  destination_type          = "NETWORK_SECURITY_GROUP"
  stateless                 = false

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_ssh_from_my_ip" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  description = "Allow SSH access from whitelisted IPs"

  source      = var.my_public_ip_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# ====================================================================
# Ingress and Egress Rules for KubeAPI between Nodes
# These rules define the ingress and egress traffic allowed between 
# worker nodes and the control plane on port 6443.
# ====================================================================
# TODO:
#   - Improve ip handling... current method of concatting is not idempotent
#   - Configure nodes to communicate over private ips in future?
# ====================================================================

# Egress rule allowing worker nodes to communicate with the load balancer on port 6443
resource "oci_core_network_security_group_security_rule" "allow_kubeapi_egress_from_workers" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_http.id
  description               = "Allow KubeAPI egress traffic from worker nodes to Load Balancer on port 6443"
  direction                 = "EGRESS"
  protocol                  = 6 # TCP
  stateless                 = false

  destination = "${oci_core_public_ip.reserved_ip.ip_address}/32" # Load Balancer's public IP

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

# Data source to fetch VNIC attachments for the control plane instance
data "oci_core_vnic_attachments" "k3s_control_plane_vnic_attachment" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.k3s_control_plane.id
}

# Fetch the VNIC details using the VNIC ID obtained from the attachment
data "oci_core_vnic" "k3s_control_plane_vnic" {
  vnic_id = data.oci_core_vnic_attachments.k3s_control_plane_vnic_attachment.vnic_attachments[0].vnic_id
}

# Data source to fetch VNIC attachments for each k3s_worker_x86 instance
data "oci_core_vnic_attachments" "k3s_worker_x86_vnic_attachments" {
  for_each       = oci_core_instance.k3s_worker_x86
  compartment_id = var.compartment_ocid
  instance_id    = each.value.id
}

# Fetch the VNIC details for each x86 worker
data "oci_core_vnic" "k3s_worker_x86_vnics" {
  for_each = data.oci_core_vnic_attachments.k3s_worker_x86_vnic_attachments
  vnic_id  = each.value.vnic_attachments[0].vnic_id
}

# Data source to fetch VNIC attachments for each k3s_worker_arm instance
data "oci_core_vnic_attachments" "k3s_worker_arm_vnic_attachments" {
  for_each       = oci_core_instance.k3s_worker_arm
  compartment_id = var.compartment_ocid
  instance_id    = each.value.id
}

# Fetch the VNIC details for each ARM worker
data "oci_core_vnic" "k3s_worker_arm_vnics" {
  for_each = data.oci_core_vnic_attachments.k3s_worker_arm_vnic_attachments
  vnic_id  = each.value.vnic_attachments[0].vnic_id
}

# Create a map of IP addresses
locals {
  # Public IPs (existing)
  k3s_control_plane_ips = [data.oci_core_vnic.k3s_control_plane_vnic.public_ip_address]
  k3s_worker_arm_ips = [for vnic in data.oci_core_vnic.k3s_worker_arm_vnics : vnic.public_ip_address]
  k3s_worker_x86_ips = [for vnic in data.oci_core_vnic.k3s_worker_x86_vnics : vnic.public_ip_address]

  # Private IPs (using existing data sources)
  k3s_control_plane_private_ips = [data.oci_core_vnic.k3s_control_plane_vnic.private_ip_address]
  k3s_worker_arm_private_ips = [for vnic in data.oci_core_vnic.k3s_worker_arm_vnics : vnic.private_ip_address]
  k3s_worker_x86_private_ips = [for vnic in data.oci_core_vnic.k3s_worker_x86_vnics : vnic.private_ip_address]

  # All public instance IPs (existing)
  all_instance_ips_map = merge(
    { "control_plane" = data.oci_core_vnic.k3s_control_plane_vnic.public_ip_address },
    { for idx, ip in local.k3s_worker_arm_ips : format("worker_arm-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_x86_ips : format("worker_x86-%d", idx) => ip }
  )

  # All private instance IPs (new, using existing data sources)
  all_private_instance_ips_map = merge(
    { "control_plane" = data.oci_core_vnic.k3s_control_plane_vnic.private_ip_address },
    { for idx, ip in local.k3s_worker_arm_private_ips : format("worker_arm-%d", idx) => ip },
    { for idx, ip in local.k3s_worker_x86_private_ips : format("worker_x86-%d", idx) => ip }
  )
}

# Security group rules
resource "oci_core_network_security_group_security_rule" "allow_kubeapi_from_workers" {
  for_each = local.all_instance_ips_map

  source                    = "${each.value}/32"
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  description               = "Allow KubeAPI ingress traffic from worker and control plane nodes on port 6443"
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  direction                 = "INGRESS"
  protocol                  = 6 # TCP

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_to_workers" {
  for_each = local.all_instance_ips_map

  destination               = "${each.value}/32"
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  description               = "Allow KubeAPI egress traffic to worker and control plane nodes on port 6443"
  destination_type          = "CIDR_BLOCK"
  stateless                 = false
  direction                 = "EGRESS"
  protocol                  = 6 # TCP

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_ingress_to_lb" {
  for_each = local.all_instance_ips_map

  source                    = "${each.value}/32"
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  description               = "Allow KubeAPI ingress traffic from worker nodes to Load Balancer on port 6443"
  direction                 = "INGRESS"
  protocol                  = 6 # TCP
  stateless                 = false

  tcp_options {
    destination_port_range {
      max = var.kube_api_port
      min = var.kube_api_port
    }
  }
}
