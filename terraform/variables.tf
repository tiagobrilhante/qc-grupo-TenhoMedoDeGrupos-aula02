variable "location" {
  # centralus: região usada pelo lab (contas Azure for Students provisionam SQL/Search lá).
  # Se sua conta bloquear, rode: terraform apply -var="location=<regiao>"
  description = "Região do Azure onde os recursos serão provisionados"
  type        = string
  default     = "centralus"
}

variable "sql_admin_password" {
  description = "Senha do admin SQL do Synapse. Gere uma forte com: openssl rand -base64 24"
  type        = string
  sensitive   = true
}