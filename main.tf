resource "google_compute_network" "vpc_network" {
  name                            = "${var.name}-01"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  #  routing_mode                    = "REGIONAL"
}

# SUBNETS
resource "google_compute_subnetwork" "subnet" {
  count                    = var.private_subnet_count
  name                     = "${var.name}-subnetwork-${count.index + 1}"
  ip_cidr_range            = cidrsubnet(var.private_subnet_cidr, 8, count.index)
  region                   = var.region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow_tcp" {
  name    = "${var.name}-firewall-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["10.0.0.0/16", "35.235.240.0/20"]
  target_tags   = ["gke-private-access"]
}

resource "google_compute_instance" "vm_instance" {
  name         = "${var.name}-instance"
  zone         = "${var.region}-b"
  tags         = ["gke-private-access"]
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet[0].self_link
  }

  service_account {
    email  = "terraform@strange-firefly-384106.iam.gserviceaccount.com"
    scopes = ["compute-ro", "storage-ro"] 
}
}
# Create GKE cluster
resource "google_container_cluster" "gke_cluster" {
  name                = "${var.name}-gke"
  location            = "${var.region}-c"
  deletion_protection = false
  network             = google_compute_network.vpc_network.name
  subnetwork          = google_compute_subnetwork.subnet[0].self_link
  logging_service     = "logging.googleapis.com/kubernetes"
  monitoring_service  = "monitoring.googleapis.com/kubernetes"

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
  }
  # maintenance_policy {
  #   daily_maintenance_window {
  #   start_time = "03:00"
  #   }
  # }

  release_channel {
    channel = "STABLE" # Use the stable release channel
  }
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Configure private cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
    #master_ipv4_cidr_block = google_compute_subnetwork.subnet[0].ip_cidr_range
  }

  # Define the authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "10.0.0.0/32"
      #cidr_block   = google_compute_instance.vm_instance.network_interface[0].network_ip
      #cidr_block = [ for subnet in google_compute_subnetwork.subnet : subnet.ip_cidr_range ]
      display_name = "Bastion-VM"
    }
  }

  # Define the node pool
  node_pool {
    name               = "${var.name}-node-pool"
    initial_node_count = 2
    node_config {
      machine_type = "e2-medium" # Adjust machine type as needed
      # Add other node configuration as needed
    }
    management {
      #auto_repair  = true
      #auto_upgrade = true
    }
    autoscaling {
      #min_node_count = 1
      #max_node_count = 3
    }
  }
}

