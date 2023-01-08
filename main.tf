terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.49.0"
    }
  }
}


provider "openstack" {
  auth_url       = "http://10.0.2.15/identity/"
  user_name   = "admin"
  tenant_name = "admin"
  password       = "password"
  domain_name    = "default"
  region         = "RegionOne"
  
}

resource "openstack_compute_instance_v2" "IAAS" {
  count          = 2
  name            = "IAAS-${count.index}"
  image_name      = "cirros-0.5.2-x86_64-disk"
  flavor_name     = "m1.tiny"
  key_pair        = "mykeypair"
  security_groups = ["${openstack_compute_secgroup_v2.secgroup_1.name}"]
    network {
    uuid = "${openstack_networking_network_v2.network_1.id}"
  }
  depends_on = [
    openstack_compute_secgroup_v2.secgroup_1,
    openstack_networking_subnet_v2.subnet_1
    ]
}

resource "openstack_networking_network_v2" "network_1" {
  name           = "network_1"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "subnet_1" {
  name       = "subnet_1"
  network_id = "${openstack_networking_network_v2.network_1.id}"
  cidr       = "192.168.199.0/24"
  ip_version = 4
   depends_on = [
    openstack_networking_network_v2.network_1
    ]
  
}

resource "openstack_compute_secgroup_v2" "secgroup_1" {
  name        = "secgroup_1"
  description = "a security group"

 rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "udp"
    cidr        = "0.0.0.0/0"
  }
    rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

# Create an external network
resource "openstack_networking_network_v2" "external_network" {
name = "external_network"
admin_state_up = "true"
external = true
}

# Create an external subnet
resource "openstack_networking_subnet_v2" "external_subnet" {
name = "external_subnet"
network_id = "${openstack_networking_network_v2.external_network.id}"
cidr = "10.0.0.0/24"
ip_version = 4
}

# Create a router and connects it to the external network
resource "openstack_networking_router_v2" "router" {
name = "router"
external_network_id = "${openstack_networking_network_v2.external_network.id}"
depends_on = [openstack_networking_subnet_v2.subnet_1]
}

# Create a router interface and connects it to the internal subnet
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id   = "${openstack_networking_router_v2.router.id}"
  subnet_id   = "${openstack_networking_subnet_v2.subnet_1.id}"
}

# Create flaoting Ip for instances
resource "openstack_networking_floatingip_v2" "floating_ip" {
count = 2
depends_on = [openstack_networking_router_v2.router]
pool = "${openstack_networking_network_v2.external_network.name}"
}

# Associating the flaoting Ips to instances
resource "openstack_compute_floatingip_associate_v2" "floating_ip_associate" {
 count = 2
  floating_ip = "${openstack_networking_floatingip_v2.floating_ip[count.index].address}"
  instance_id = "${openstack_compute_instance_v2.IAAS[count.index].id}"
}

resource "openstack_blockstorage_volume_v3" "volume" {

count = 2

name = "my-volume-${count.index}"

size = 1

description = "Block storage volume for IaaS-${count.index}"

volume_type = "lvmdriver-1 "


}
resource "openstack_compute_volume_attach_v2" "attach" {

  count       = 2

  volume_id   = "${openstack_blockstorage_volume_v3.volume[count.index].id}"

  instance_id = "${openstack_compute_instance_v2.IAAS[count.index].id}"

  device      = "/dev/vdb"

  depends_on = [

    openstack_compute_instance_v2.IAAS,

    openstack_blockstorage_volume_v3.volume

  ]

}


