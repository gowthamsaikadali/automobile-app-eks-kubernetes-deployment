output "db_endpoint" {
  description = "Host:port endpoint for the RDS instance"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Host only (no port) - use this for DB_HOST"
  value       = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_security_group_id" {
  value = aws_security_group.db.id
}
