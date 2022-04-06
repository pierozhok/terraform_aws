variable "tags" {
  type = object({
    Name    = string
    Owner   = string
    Project = string
  })
  default = (
    {
    Name    = "spbdki-19"
    Owner   = "alakimov"
    Project = "internship"
    })
}

variable "enable_standalone_ec2" {
  type = bool
  default = false
}

variable "number_ec2" {
  type = number
  default = 1
}

variable "docker_image" {
  type = string
}