# Creating RDS PostgreSQL instance in private subnets - database is not publicly accessible, only EC2 instances can reach it
# multi_az - AWS automatically creates a standby replica in another AZ, if primary fails it switches over automatically
# backup_retention_period - AWS keeps automatic backups for 7 days so we can restore to any point in time
# skip_final_snapshot false - creates a snapshot before destroying the instance so we never lose data by accident
# storage_encrypted - all data stored on disk is encrypted using KMS
resource "aws_db_instance" "rds_db_instance" {
  allocated_storage         = 10
  db_name                   = "wenttoprod"
  engine                    = "postgres"
  engine_version            = "16"
  instance_class            = "db.t3.micro"
  username                  = var.db_username
  password                  = var.db_password
  parameter_group_name      = "default.postgres16"
  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "wenttoprod-final-snapshot"
  storage_encrypted         = true
  publicly_accessible       = false
  multi_az                  = true
  db_subnet_group_name      = data.terraform_remote_state.network.outputs.subnet_group_id
  vpc_security_group_ids    = [data.terraform_remote_state.network.outputs.rds_security_group]
}

# Creating SSM Parameter with database connection string - stored as SecureString so value is encrypted using KMS
# EC2 instances fetch this parameter at startup to connect to RDS without hardcoding credentials anywhere in the code
resource "aws_ssm_parameter" "db_connection_string" {
  name  = "/prod/db-connection-string"
  type  = "SecureString"
  value = "Host=${aws_db_instance.rds_db_instance.address};Port=5432;Database=wenttoprod;Username=${var.db_username};Password=${var.db_password}"
}