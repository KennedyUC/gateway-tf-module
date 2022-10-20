// define the manifest files
data "kubectl_path_documents" "issuer_manifest" {
    pattern = "./manifests/cluster-issuer/*.yaml"
}

data "kubectl_path_documents" "cert_manifest" {
    pattern = "./manifests/certificate/*.yaml"
}

data "kubectl_path_documents" "gateway_manifest" {
    pattern = "./manifests/gateway/*.yaml"
}

data "kubectl_path_documents" "testpage_manifest" {
    pattern = "./manifests/test-page/*.yaml"
}


resource "helm_release" "istio_gateway" {
  name             = "istio-ingressgateway"
  repository       = var.istio_chart_repo
  chart            = "gateway"
  namespace        = var.istio_namespace
  create_namespace = false
  values           = [
    file("./helm_values/istio-gateway-values.yaml")]
  atomic           = true
}


// create the certificate issuer resource
resource "kubectl_manifest" "issuer_manifest" {
    count     = length(data.kubectl_path_documents.issuer_manifest.documents)
    yaml_body = element(data.kubectl_path_documents.issuer_manifest.documents, count.index)
}

// create the certificate issuer resource
resource "kubectl_manifest" "cert_manifest" {
    depends_on  = [kubectl_manifest.issuer_manifest]
    count       = length(data.kubectl_path_documents.cert_manifest.documents)
    yaml_body   = element(data.kubectl_path_documents.cert_manifest.documents, count.index)
}

// create the istio gateway resource
resource "kubectl_manifest" "gateway_manifest" {
    depends_on  = [kubectl_manifest.cert_manifest]
    count       = length(data.kubectl_path_documents.gateway_manifest.documents)
    yaml_body   = element(data.kubectl_path_documents.gateway_manifest.documents, count.index)
}

// create the testpage resource
resource "kubectl_manifest" "testpage_manifest" {
    depends_on  = [kubectl_manifest.gateway_manifest]
    count       = length(data.kubectl_path_documents.testpage_manifest.documents)
    yaml_body   = element(data.kubectl_path_documents.testpage_manifest.documents, count.index)
}