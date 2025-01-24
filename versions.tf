terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kaniko = {
      source  = "seal-io/kaniko"
      version = "0.0.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
  }
}
