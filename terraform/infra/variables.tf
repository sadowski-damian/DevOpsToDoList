variable "instance_type" {
  type        = string
  description = "EC2 instance type (t3.micro or t2.micro)"
  default     = "t3.micro"

  validation {
    condition     = var.instance_type == "t3.micro" || var.instance_type == "t2.micro"
    error_message = "EC2 instance has to be type t3.micro or t2.micro"
  }
}