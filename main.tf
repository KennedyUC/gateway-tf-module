// create the certificate issuer resource
resource "kubectl_manifest" "issuer_manifest" {
    yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cluster
  namespace: istio-system
spec:
  acme:
    email: kennedy@mavencode.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-cluster
    solvers:
    - http01:
        ingress:
          class: istio
YAML
}

// create the certificate issuer resource
resource "kubectl_manifest" "cert_manifest" {
    depends_on  = [kubectl_manifest.issuer_manifest]
    yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kenn-domain-cert
  namespace: istio-system
spec:
  secretName: kenn-domain-cert
  duration: 2160h
  renewBefore: 360h
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
    - "alpinresorts.online"
  issuerRef:
    name: letsencrypt-cluster
    kind: ClusterIssuer
    group: cert-manager.io
YAML
}

// create the istio gateway resource
resource "kubectl_manifest" "gateway_manifest" {
    depends_on  = [kubectl_manifest.cert_manifest]
    yaml_body = <<YAML
    apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "alpinresorts.online"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: kenn-domain-cert
    hosts:
    - "alpinresorts.online"
YAML
}

// create the virtualservice resource
resource "kubectl_manifest" "virtualservice_manifest" {
    depends_on  = [kubectl_manifest.gateway_manifest]
    yaml_body = <<YAML
    apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: virtual-service-test
  namespace: default
spec:
  hosts:
  - "alpinresorts.online"
  gateways:
  - istio-system/gateway
  http:
  - match:
    - uri:
        exact: /
    route:
    - destination:
        host: test-app-service
        port:
          number: 8080
YAML
}