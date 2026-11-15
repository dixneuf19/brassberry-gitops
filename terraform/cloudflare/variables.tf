variable "mangococo_email_forwards" {
  description = "Source address on mangococo.fr => destination mailboxes (bws secret mangococo-email-forwards)"
  type        = map(list(string))
  sensitive   = true

  validation {
    condition     = alltrue([for src in keys(var.mangococo_email_forwards) : endswith(lower(src), "@mangococo.fr")])
    error_message = "Every source address must be on mangococo.fr."
  }
}
