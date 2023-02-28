variable "app" {
  description = "The app name"
  default     = "csgo"
}

variable "env" {
  description = "The environment for the current application"
  default     = "prod"
}

variable "subnet_id" {
  description = "The subnet id in which to deploy the server. It must be a public subnet."
  validation {
    condition     = coalesce(var.subnet_id, "") != ""
    error_message = "subnet_id is required."
  }
}

variable "tickrate" {
  description = "The server tickrate, defaults to 64"
  default     = 64
}


variable "instance_type" {
  description = "AWS Instance Type"
  default     = "t3.medium"
}

variable "gslt" {
  description = "Steam Token"
  default     = ""
  validation {
    condition     = var.gslt != ""
    error_message = "gslt is required."
  }
}

variable "max_players" {
  default = "32"
}

variable "slack_webhook_url" {
  default = ""
}

variable "sv_password" {
  default = ""
}

variable "sv_contact" {
  default = ""
}

variable "sv_tags" {
  default = "64-tick,casual,dust2,ZRP"
}

variable "sv_region" {
  default = "255"
}
