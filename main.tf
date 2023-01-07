

# Define required providers
terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.48.0"
    }
  }
}
#-----------------------------------------------------------------------
provider "openstack" {
  auth_url       = "http://10.0.2.15/identity/"
  user_name   = "admin"
  tenant_name = "admin"
  password       = "password"
  domain_name    = "default"
  region         = "RegionOne"
}
#------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "IAAS" {
  name            = "IAAS"
  image_name      = "cirros-0.5.2-x86_64-disk"
  flavor_name     = "m1.tiny"
  key_pair        = "mykeypair"
  security_groups = ["default"]
    network {
    uuid = "${openstack_networking_network_v2.network_1.id}"
  }
}
#--------------------------------------------------------------------------

resource "openstack_networking_network_v2" "network_1" {
  name           = "network_1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_1" {
  name       = "subnet_1"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  cidr       = "192.168.199.0/24"
  ip_version = 4
}

resource "openstack_compute_secgroup_v2" "secgroup_1" {
  name        = "secgroup_1"
  description = "a security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_networking_port_v2" "port_1" {
  name               = "port_1"
  network_id         = "${openstack_networking_network_v2.network_1.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.secgroup_1.id}"]

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
     }
  
}
#-------------------------------------------------------------------------------------
resource "openstack_networking_network_v2" "external_network" {
  name           = "external_network"
  admin_state_up = "true"
  external       = true
}

resource "openstack_networking_subnet_v2" "floatingip_subnet" {
  name       = "floatingip_subnet"
  network_id = "${openstack_networking_network_v2.external_network.id}"
  cidr       = "172.16.0.0/12"
  ip_version = 4
}
resource "openstack_compute_secgroup_v2" "external_secgroup" {
  name        = "external_secgroup"
  description = "a security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_networking_port_v2" "external_port" {
  name               = "external_port"
  network_id         = "${openstack_networking_network_v2.external_network.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.external_secgroup.id}"]

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.floatingip_subnet.id}"
     }
  
}

resource "openstack_networking_floatingip_v2" "floating_ip" {
  pool      = "external_network"
  subnet_id = "${openstack_networking_subnet_v2.floatingip_subnet.id}"
  port_id   = "${openstack_networking_port_v2.external_port.id}"
}
resource "openstack_networking_router_v2" "router" {
name = "my-router"
external_network_id = "${openstack_networking_network_v2.external_network.id}"
}

resource "openstack_networking_router_interface_v2" "router_interface" {
router_id = "${openstack_networking_router_v2.router.id}"
subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}
resource "openstack_compute_floatingip_associate_v2" "associate_floating_ip" {
  floating_ip = "${openstack_networking_floatingip_v2.floating_ip.address}"
  instance_id = "${openstack_compute_instance_v2.IAAS.id}"
}



