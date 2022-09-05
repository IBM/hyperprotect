# generate a temporary key pair
resource "tls_private_key" "ssh_key" {
  algorithm   = "RSA"
}

# Save private key so that we can use this to ssh into the instance
resource "local_sensitive_file" "private_key" {
    content  = tls_private_key.ssh_key.private_key_openssh
    filename = "private_key"
}

# Write public key for debugging
resource "local_sensitive_file" "public_key" {
    content  = trimspace(tls_private_key.ssh_key.public_key_openssh)
    filename = "public_key"
}
