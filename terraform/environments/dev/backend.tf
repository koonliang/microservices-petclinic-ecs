terraform {
  backend "s3" {
    bucket         = "petclinic-tfstate-309779120361"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "petclinic-terraform-locks"
  }
}
