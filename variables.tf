variable "acme_email" {
    type        = string
    default     = "kennedy@mavencode.com"
    description = "acme user email"
}

variable "app_namespace" {
    type        = string
    default     = "test-app"
    description = "namespace to deploy the test app"
}

variable "app_name" {
    type        = string
    default     = "test-app"
    description = "name of the app for the test"
}

variable "certificate_name" {
    type        = string
    description = "certificate name"
}

variable "issuer_name" {
    type        = string
    description = "certificate cluster issuer name"
}