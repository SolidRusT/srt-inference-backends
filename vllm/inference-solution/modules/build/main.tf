# Local values for the build process
locals {
  app_path          = "${path.root}/app"
  dockerfile_path   = "${local.app_path}/Dockerfile"
  build_script_path = "${path.module}/scripts/build_and_push.sh"
}

# Create a null_resource for building and pushing the Docker image
resource "null_resource" "build_and_push" {
  triggers = {
    # Rebuild when any of these files change
    app_code_hash    = filesha256("${local.app_path}/server.js")
    dockerfile_hash  = filesha256(local.dockerfile_path)
    package_json_hash = filesha256("${local.app_path}/package.json")
  }

  provisioner "local-exec" {
    command = "bash ${local.build_script_path} ${var.ecr_repository_url} ${var.aws_region} ${local.app_path}"
  }

  depends_on = [var.ecr_repository_url]
}

# Output resource for checking if build has been completed
resource "null_resource" "build_completed" {
  depends_on = [null_resource.build_and_push]
}
