data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["137112412989"] # ami ID amazon "ami-08188dffd130a1ac2"

  filter {
    name   = "name"
    values = ["al2023-ami-2023*x86_64"]
  }
}

