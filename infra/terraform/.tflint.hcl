# Shared TFLint configuration for every module and environment root in this
# tree. CI runs tflint with --chdir per directory and --config pointing here,
# so rule policy lives in exactly one place.

tflint {
  required_version = ">= 0.50"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "google" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Naming consistency is enforced, not suggested: a mixed-convention tree reads
# like it has multiple owners and none of them responsible.
rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
