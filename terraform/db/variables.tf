# Variable passed from HCP Terraform - sensitive = true so value is masked in plan/apply
variable "db_username" {
  type      = string
  sensitive = true
}

# Variable passed from HCP Terraform - sensitive = true
variable "db_password" {
  type      = string
  sensitive = true
}