terraform {
  backend "s3" {
    bucket = "terrafrom-amodh-jaiswal-v"
    key    = "project/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
