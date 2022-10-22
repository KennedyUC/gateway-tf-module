// create the certificate issuer resource
resource "kubectl_manifest" "issuer_manifest" {
    yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-test-cluster-issuer
      namespace: cert-manager
    spec:
      acme:
        email: ${var.acme_email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-test-issuer-key
        solvers:
        - http01:
            ingress:
              class: nginx
    YAML
}

// // create the istio gateway resource
// resource "kubectl_manifest" "gateway_manifest" {
//     depends_on  = [kubectl_manifest.cert_manifest]
//     yaml_body = <<YAML
//     apiVersion: networking.istio.io/v1alpha3
//     kind: Gateway
//     metadata:
//       name: prod-gateway
//       namespace: istio-system
//     spec:
//       selector:
//         istio: ingressgateway
//       servers:
//       - port:
//           number: 80
//           name: http
//           protocol: HTTP
//         hosts:
//         - test.alpinresorts.online
//       - port:
//           number: 443
//           name: https
//           protocol: HTTPS
//         tls:
//           mode: SIMPLE
//           credentialName: letsencrypt-test-domain-certificate
//         hosts:
//         - test.alpinresorts.online
//     YAML
// }

// create the test app deployment resource
resource "kubectl_manifest" "app_namespace" {
    depends_on  = [kubectl_manifest.issuer_manifest]
    yaml_body = <<YAML
    kind: Namespace
    apiVersion: v1
    metadata:
      name: ${var.app_namespace}
      labels:
        name: ${var.app_namespace}
    YAML
}

// // create the virtualservice resource
// resource "kubectl_manifest" "virtualservice_manifest" {
//     depends_on  = [kubectl_manifest.app_namespace]
//     yaml_body = <<YAML
//     apiVersion: networking.istio.io/v1alpha3
//     kind: VirtualService
//     metadata:
//       name: virtual-service-test
//       namespace: ${var.app_namespace}
//     spec:
//       hosts:
//       - "test.alpinresorts.online"
//       gateways:
//       - istio-system/gateway
//       http:
//       - match:
//         - uri:
//             exact: /
//         route:
//         - destination:
//             host: ${var.app_name}
//             port:
//               number: 8080
//     YAML
// }

// create the test app deployment resource
resource "kubectl_manifest" "test_app_resource" {
    depends_on  = [kubectl_manifest.app_namespace]
    yaml_body = <<YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${var.app_name}
      namespace: ${var.app_namespace}
    spec:
      selector:
        matchLabels:
          app: ${var.app_name}
      template:
        metadata:
          labels:
            app: ${var.app_name}
        spec:
          containers:
          - name: ${var.app_name}
            image: nginxdemos/hello
            resources:
              limits:
                memory: "128Mi"
                cpu: "500m"
            ports:
            - containerPort: 8080
    YAML
}

// create the test app service
resource "kubectl_manifest" "test_app_service" {
    depends_on  = [kubectl_manifest.test_app_resource]
    yaml_body = <<YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: ${var.app_name}
      namespace: ${var.app_namespace}
    spec:
      selector:
        app: ${var.app_name}
      ports:
        - protocol: TCP
          port: 8080
          targetPort: 80
    YAML
}

// create the certificate issuer resource
resource "kubectl_manifest" "certificate_resource" {
    depends_on  = [kubectl_manifest.test_app_service]
    yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: letsencrypt-test-domain-certificate
      namespace: ${var.app_namespace}
    spec:
      secretName: letsencrypt-test-domain-certificate
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
        - test.alpinresorts.online
      issuerRef:
        name: letsencrypt-test-cluster-issuer
        kind: ClusterIssuer
        group: cert-manager.io
    YAML
}

// create the ingress for the service
resource "kubectl_manifest" "ingress_resource" {
    depends_on  = [kubectl_manifest.certificate_resource]
    yaml_body = <<YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: letsencrypt-test-ingress
      annotations:
        kubernetes.io/ingress.class: "nginx"
        nginx.ingress.kubernetes.io/ssl-redirect: "false" 
        certmanager.k8s.io/issuer: "letsencrypt-test-cluster-issuer"
        certmanager.k8s.io/acme-challenge-type: http01
    spec:
      tls:
      - hosts:
        - test.alpinresorts.online
        secretName: letsencrypt-test-domain-certificate
      rules:
      - host: test.alpinresorts.online
        http:
          paths:
          - path: /
            pathType: Exact
            backend:
              service:
                name: ${var.app_name}
                port: 
                  number: 80
    YAML
}