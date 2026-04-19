# Database username - passed as sensitive variable from HCP Terraform Cloud, value is masked in plan and apply output
variable "db_username" {
  type      = string
  sensitive = true
}

# Database password - passed as sensitive variable from HCP Terraform Cloud, value is masked in plan and apply output
variable "db_password" {
  type      = string
  sensitive = true
}