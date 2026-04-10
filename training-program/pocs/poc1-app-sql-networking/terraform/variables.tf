variable "location"           { type = string; default = "eastus2" }
variable "environment"        { type = string; default = "dev" }
variable "project"            { type = string; default = "poc1" }
variable "team"               { type = string; default = "platform" }
variable "cost_center"        { type = string; default = "engineering" }
variable "app_service_sku"    { type = string; default = "P1v3" }
variable "sql_admin_username" { type = string; default = "sqladmin" }
variable "sql_admin_password" { type = string; sensitive = true }
