# Create RDS Postgres instance, we pass subnet group name and security groups using remote state (network workspace)
resource "aws_db_instance" "rds_db_instance" {
  allocated_storage      = 10
  db_name                = "wenttoprod"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres16"
  skip_final_snapshot    = true
  storage_encrypted      = true
  publicly_accessible    = false
  db_subnet_group_name   = data.terraform_remote_state.network.outputs.subnet_group_id
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.rds_security_group]
}

# Add SSM parameter - /prod/db-connection-string, username and password passed from HCP variables
# Secure string means that value is encrypted at rest using KMS also hidden in AWS Console and CLI
resource "aws_ssm_parameter" "db_connection_string" {
  name  = "/prod/db-connection-string"
  type  = "SecureString"
  value = "Host=${aws_db_instance.rds_db_instance.address};Port=5432;Database=wenttoprod;Username=${var.db_username};Password=${var.db_password}"
}