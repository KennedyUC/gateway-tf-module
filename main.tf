// define the path to the manifest files
data "kubectl_path_documents" "manifests" {
    pattern = "./manifests/*.yaml"
}

// install the manifest files
resource "kubectl_manifest" "istio-gateway" {
    for_each     = toset(data.kubectl_path_documents.manifests.documents)
    yaml_body    = each.value
}