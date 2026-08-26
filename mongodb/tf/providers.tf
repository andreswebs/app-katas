# Credentials come from the environment, never from a .tfvars in the tree.
# Either the programmatic API key pair:
#   MONGODB_ATLAS_PUBLIC_KEY / MONGODB_ATLAS_PRIVATE_KEY
# or the service account pair the 2.x provider accepts:
#   MONGODB_ATLAS_CLIENT_ID / MONGODB_ATLAS_CLIENT_SECRET
provider "mongodbatlas" {}

provider "random" {}
