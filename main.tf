#
# Random number
#

resource "random_password" "random" {
  length  = 4
  special = false
  upper   = false
}

#
# Build
#

data "template_file" "no_container_image_template" {
  template = file("${path.module}/kpack-image.yaml.tpl")
  vars     = {
    name            = var.name,
    registry_server = var.registry_server,
    image           = var.image,
    git_url         = var.git_url,
    tag_or_branch   = local.tag_or_branch,
    random_value    = local.random_value
  }
}

data "kubectl_file_documents" "no_container_image_file" {
  content = data.template_file.no_container_image_template.rendered
}

resource "kubectl_manifest" "no_container_image" {
  depends_on = [data.kubectl_file_documents.no_container_image_file]
  
  for_each  = data.kubectl_file_documents.no_container_image_file.manifests
  yaml_body = each.value
}

# Add delay to wait for the image to be uploaded into the registry

resource "time_sleep" "delay" {
  create_duration = "300s"
}

module "image_pull_secrets" {
  count = var.registry_auth ? 1 : 0

  depends_on = [resource.time_sleep.delay]

  source    = "./modules/image-pull-secret"
  name      = local.name
  namespace = local.namespace
  server    = var.registry_server
  username  = var.registry_username
  password  = var.registry_password
}

########
# Deploy 
########

module "deployment" {
  depends_on = [resource.time_sleep.delay]

  # disable wait for all pods be ready.
  #
  wait_for_rollout = false

  # Use local paths to avoid accessing external networks
  # This module comes from terraform registry "terraform-iaac/deployment/kubernetes 1.4.2"
  source = "./modules/deployment"

  name      = local.name
  namespace = local.namespace
  image     = "${var.registry_server}/${var.image}"
  image_pull_secrets = var.registry_auth ? {
    (local.name) : data.kubernetes_secret.image_pull_secrets.metadata[0].name
  } : {}
  replicas = var.replicas
  resources = {
    request_cpu    = var.request_cpu == "" ? null : var.request_cpu
    limit_cpu      = var.limit_cpu == "" ? null : var.limit_cpu
    request_memory = var.request_memory == "" ? null : var.request_memory
    limit_memory   = var.limit_memory == "" ? null : var.limit_memory
  }
  env = var.env
}

module "service" {
  depends_on = [resource.time_sleep.delay]

  # Use local paths to avoid accessing external networks
  # This module comes from terraform registry "terraform-iaac/service/kubernetes 1.0.4"
  source = "./modules/service"

  app_name      = local.name
  app_namespace = local.namespace
  type          = "NodePort"
  port_mapping = [for p in var.ports :
    {
      name          = "port-${p}"
      internal_port = p
      external_port = p
      protocol      = "TCP"
  }]
}

module "ingress" {
  count = var.ingress_enabled ? 1 : 0

  depends_on         = [module.deployment, module.service]
  source             = "./modules/ingress"
  app_name           = local.name
  app_namespace      = local.namespace
  annotations        = var.ingress_annotations
  ingress_class_name = var.ingress_class_name
  http_rules = [{
    host     = var.ingress_host
    resource = []
    service = [{
      name        = data.kubernetes_service.service.metadata[0].name
      port_number = data.kubernetes_service.service.spec[0].port[0].port
      # port_name   = data.kubernetes_service.service.spec[0].port[0].name
    }]
  }]
  tls_rules = var.ingress_tls_enabled ? [{
    hosts       = [var.ingress_host]
    secret_name = replace(var.ingress_host, ".", "-")
  }] : []
}

data "kubernetes_secret" "image_pull_secrets" {
  depends_on = [resource.time_sleep.delay]

  metadata {
    name      = local.name
    namespace = local.namespace
  }
}

data "kubernetes_service" "service" {
  depends_on = [module.service]

  metadata {
    name      = local.name
    namespace = local.namespace
  }
}

data "kubernetes_ingress_v1" "ingress" {
  depends_on = [module.ingress]

  metadata {
    name      = local.name
    namespace = local.namespace
  }
}

locals {
  context        = var.context
  name           = coalesce(try(var.name, null), try(var.walrus_metadata_service_name, null), try(var.context["resource"]["name"], null))
  namespace      = coalesce(try(var.namespace, null), try(var.walrus_metadata_namespace_name, null), try(var.context["environment"]["namespace"], null))
  formal_git_url = replace(var.git_url, "https://", "git://")
  tag_or_branch  = "${var.git_tag != "" ? var.git_tag : var.git_branch}"
  random_value   = random_password.random.result
}

#######
# HPA
#######

module "keda_scaleobject" {
  depends_on         = [module.deployment, module.service]

  # Use local paths to avoid accessing external networks
  # This module comes from terraform registry "terraform-iaac/deployment/kubernetes 1.0.0"
  source = "./modules/keda"

  name         = local.name
  namespace    = local.namespace
  replicas     = var.replicas
  limit_cpu    = var.limit_cpu == "" ? null : var.limit_cpu
  limit_memory = var.limit_memory == "" ? null : var.limit_memory
}