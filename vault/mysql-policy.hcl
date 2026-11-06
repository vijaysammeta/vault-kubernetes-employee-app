# HashiCorp Vault Policy
# Policy Name: mysql-policy

path "secret/data/mysql" {
  capabilities = ["read"]
}
