terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-aiops-lab"
}

resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = "tofu-lab"
  }
}
