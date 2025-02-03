apiVersion: kpack.io/v1alpha2
kind: Image
metadata:
  name: ${name}-${tag}
  namespace: kpack
spec:
  tag: ${registry_server}/${image}
  serviceAccountName: harbor-service-account
  builder:
    name: docker-cluster-builder
    kind: ClusterBuilder
  source:
    git:
      url: ${git_url}
      revision: ${tag_or_branch}