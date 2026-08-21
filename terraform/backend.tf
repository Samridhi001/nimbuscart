terraform {
  backend "s3" {
    bucket         = "nimbuscart-terraform-state-281525601825"
    key            = "nimbuscart/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "nimbuscart-terraform-locks"
  }
}
