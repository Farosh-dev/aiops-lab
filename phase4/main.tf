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

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "web-tofu"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "web-tofu"
      }
    }

    template {
      metadata {
        labels = {
          app = "web-tofu"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "web-tofu"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }

  spec {
    selector = {
      app = "web-tofu"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}
