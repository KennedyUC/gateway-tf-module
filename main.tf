// create the certificate issuer resource
resource "kubectl_manifest" "issuer_manifest" {
    yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod-cluster
      namespace: istio-system
    spec:
      acme:
        email: ${var.acme_email}
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
      name: prod-domain-cert
      namespace: istio-system
    spec:
      secretName: prod-domain-cert
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
        name: letsencrypt-prod-cluster
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
      name: prod-gateway
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
          credentialName: prod-domain-cert
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
      namespace: app-test
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

// create the test app deployment resource
resource "kubectl_manifest" "app_namespace" {
    depends_on  = [kubectl_manifest.virtualservice_manifest]
    yaml_body = <<YAML
    kind: Namespace
    apiVersion: v1
    metadata:
      name: ${var.app_namespace}
      labels:
        name: ${var.app_namespace}
    YAML
}

// create the test app deployment resource
resource "kubectl_manifest" "test_app_deployment" {
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
    depends_on  = [kubectl_manifest.test_app_deployment]
    yaml_body = <<YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: test-app-service
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