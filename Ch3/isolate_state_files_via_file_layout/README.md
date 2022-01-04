
# Isolate state files via file layout

To achieve full isolation between different environments, you need separate modules for
each environment (stage, prod). Configure a separate backend for each environment (
with separate S3 bucket and IAM account access).
Since there are some components you will deploy only once - and change rarely - like
VPCs, and associated subnets, VPNs, routing rules, and ACLs, these should be in a
separate modules (thus separate state files) for these.
Some common configuration like IAM, S3 can be in a separate module.
Inside each environment module, you should split into VPC, services, and data-storage modules.
Each module will generate a separate tfstate file.
If you feel your main.tf file is getting massive in any module, you can split it up into
multiple files. Probably, in that case, you should split up the module into multiple modules.

# General final layout

stage
  + vpc
  - services
    + frontend
    - backend
      - var.tf     # for input variables
      - outputs.tf # for output variables
      - main.tf    # for creating AWS resources
  - data-storage
    + mysql
    + redis
prod
  + vpc
  - services
    + frontend
    - backend
      - var.tf     # for input variables
      - outputs.tf # for output variables
      - main.tf    # for creating AWS resources
  - data-storage
    + mysql
    + redis
mgmt
  + vpc
  - services
    + bastion-host
    + jenkins
global
  + iam
  + s3

# Let's create modules for the webserver we created in this chapter like this:

stage
  - services
    + webserver-cluster
      - var.tf
      - outputs.tf
      - main.tf
  - data-stores
    - mysql
      - var.tf
      - outputs.tf
      - main.tf
global
  - s3
    - outputs.tf
    - main.tf

# Issues with modular structure:

 - you have to issue commands in each module to get your entire infrastructure up.
 - difficult to use resource dependencies. Fortunately, the terraform_remote_state data
   source can be used to help with this.



