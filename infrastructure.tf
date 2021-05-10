variable "project" {}

variable "postgres_user" {
  default = "airflow"
}
variable "postgres_pw" {
  default = "airflow"
}

variable "region" {
  default = "asia-southeast1"
}

variable "zone" {
  default = "asia-southeast1-a"
}

provider "google" {
  version = "3.66.1"
  project = "${var.project}"
  region = "${var.region}"
}

resource "google_compute_global_address" "airflow-static-ip" {
  name = "airflow-static-ip"
}

resource "google_compute_disk" "airflow-redis-disk" {
  name  = "airflow-redis-disk"
  type  = "pd-ssd"
  size = "200"
  zone  = "${var.zone}"
}

resource "google_sql_database_instance" "airflow-db" {
  name = "airflow-db"
  database_version = "POSTGRES_9_6"
  region = "${var.region}"
  settings {
    tier = "db-g1-small"
  }
}

resource "google_sql_database" "airflow-schema" {
  name = "airflow"
  instance = "${google_sql_database_instance.airflow-db.name}"
}

resource "google_sql_user" "proxyuser" {
  name = "${var.postgres_user}"
  password = "${var.postgres_pw}"
  instance = "${google_sql_database_instance.airflow-db.name}"
  host = "cloudsqlproxy~%"
}

resource "google_compute_subnetwork" "gke-subnet" {
  name = "gkesubnet"
  ip_cidr_range = "10.168.0.0/26"
  region = "${var.region}"
  network = google_compute_network.vpc.id
  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.1.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-ranges"
    ip_cidr_range = "192.168.64.0/22"
  }
}

resource "google_compute_network" "vpc" {
  name = "airflow-network"
  auto_create_subnetworks = false
}


resource "google_container_cluster" "airflow-cluster" {
  name = "airflow-cluster"
  location = "${var.zone}"
  initial_node_count = "1"
  node_config {
    machine_type = "n1-standard-4"
    oauth_scopes = ["https://www.googleapis.com/auth/devstorage.read_only"]
  }
  network = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.gke-subnet.id
  
  ip_allocation_policy {
    cluster_secondary_range_name = "services-range"
    services_secondary_range_name = google_compute_subnetwork.gke-subnet.secondary_ip_range.1.range_name
  }
}
