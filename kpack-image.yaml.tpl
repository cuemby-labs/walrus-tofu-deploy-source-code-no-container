apiVersion: kpack.io/v1alpha2
kind: Image
metadata:
  name: ${name}
  namespace: kpack
spec:
  tag: ${registry_server}/${image}
  serviceAccountName: docker-service-account
  builder:
    name: docker-builder
    kind: Builder
  source:
    git:
      url: ${git_url}
      revision: ${tag_or_branch}