variable "name" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "description" {
  description = "A short description of the repository"
  type        = string
  default     = ""
}

variable "visibility" {
  description = "The visibility of the repository. Can be 'public' or 'private'"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "Visibility must be 'public' or 'private'."
  }
}
