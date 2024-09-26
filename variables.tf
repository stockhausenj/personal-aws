variable "create_instance" {
  description = "Create instance."
  type        = bool
  default     = "true"
}

variable "instance_schedule" {
  description = "Instance schedule to use."
  type        = string
  default     = "stop-at-10"

  validation {
    condition     = var.create_instance == true ? length(var.instance_schedule) > 0 : true
    error_message = "You must pick a schedule if create_instance is true."
  }
}
