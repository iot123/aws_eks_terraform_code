resource "aws_key_pair" "keypair" {
  key_name = "cluster-${var.env}-${var.workspace}"

  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQClILaXZaFqOYd02yNg/zowzoEiATAeOd7tQHTDfhK6QljEZw7mX3TIvI2lD7qOWVLIfJdehbFmMlpkMvK03IQvY82Lr5L8l/uklabBR/eyYF63c0QiApxQkCPtLtNkLGgBqxiNudKIRoIxwbTfX5ER2X7ueeotZKU8ybraR3YMpALgn7OoMu6z8vF4d4rQnjvaTc7fq9IqOuBPj2dBDW39tgdLJlYD+Hy4m+Wx239fSMxFEvHUzTpb+PGh2+wU4MzpyiO/jET+BHzRuhVQQSzyJiysoG8yMkr3cOegKG8VQMb5srfV9I5jZeceJ6cwSw5alodS580cWda+bD/5xLQj rahul_jump"
}
