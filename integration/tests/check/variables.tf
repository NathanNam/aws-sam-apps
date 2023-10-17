variable "program" {
  description = <<-EOF
    A list of strings, whose first element is the program to run and whose
    subsequent elements are optional command line arguments to the program.
    Terraform does not execute the program through a shell, so it is not
    necessary to escape shell metacharacters nor add quotes around arguments
    containing spaces.
  EOF
  type        = list(string)
  nullable    = false
}

variable "query" {
  description = <<-EOF
    A map of string values to pass to the external program as the query
    arguments. If not supplied, the program will receive an empty object as its
    input.
  EOF
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "working_dir" {
  description = "Working directory of the program"
  type        = string
  default     = null
}
