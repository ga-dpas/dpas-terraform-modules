data "aws_ssm_parameter" "ami" {
  name = local.ami_type_to_ssm_param[var.ami_type]
}

locals {
  ami_type_to_user_data_type = {
    AL2_x86_64             = "linux"
    AL2_ARM_64             = "linux"
    AL2023_x86_64_STANDARD = "al2023"
    AL2023_ARM_64_STANDARD = "al2023"
  }

  # Map the AMI type to the respective SSM param path
  ami_type_to_ssm_param = {
    AL2_x86_64             = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
    AL2_ARM_64             = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2-arm64/recommended/image_id"
    AL2023_x86_64_STANDARD = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
    AL2023_ARM_64_STANDARD = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/arm64/standard/recommended/image_id"
  }

  user_data_type = local.ami_type_to_user_data_type[var.ami_type]

  template_path = {
    al2023 = "${path.module}/templates/al2023_userdata.tpl"
    linux  = "${path.module}/templates/linux_userdata.tpl"
  }

  image_id    = coalesce(var.ami_id, nonsensitive(data.aws_ssm_parameter.ami.value))
  node_labels = coalesce(var.node_labels, "cluster=${var.cluster_id},ami-id=${local.image_id}")
  user_data = base64encode(templatefile(local.template_path[local.user_data_type],
    {
      cluster_id            = aws_eks_cluster.eks.id
      endpoint              = aws_eks_cluster.eks.endpoint
      certificate_authority = aws_eks_cluster.eks.certificate_authority.0.data

      cluster_service_cidr = var.cluster_service_cidr
      cluster_ip_family    = var.cluster_ip_family

      # Optional
      extra_userdata       = var.extra_userdata
      bootstrap_extra_args = var.bootstrap_extra_args
      node_labels          = var.node_labels
    }
  ))
}

################################################################################
# Launch template
################################################################################
resource "aws_launch_template" "node" {
  name_prefix   = "${var.cluster_id}-node-"
  image_id      = coalesce(var.ami_id, nonsensitive(data.aws_ssm_parameter.ami.value))
  instance_type = var.default_worker_instance_type

  user_data = local.user_data

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node.id
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.eks_node.id]
    delete_on_termination       = true
  }

  lifecycle {
    create_before_destroy = true
  }

  # root volume
  block_device_mappings {
    device_name = try(var.root_block_device_mappings.device_name, null)
    ebs {
      delete_on_termination = try(var.root_block_device_mappings.ebs.delete_on_termination, null)
      encrypted             = try(var.root_block_device_mappings.ebs.encrypted, null)
      iops                  = try(var.root_block_device_mappings.ebs.iops, null)
      kms_key_id            = try(var.root_block_device_mappings.ebs.kms_key_id, null)
      snapshot_id           = try(var.root_block_device_mappings.ebs.snapshot_id, null)
      throughput            = try(var.root_block_device_mappings.ebs.throughput, null)
      volume_size           = try(var.root_block_device_mappings.ebs.volume_size, null)
      volume_type           = try(var.root_block_device_mappings.ebs.volume_type, null)
    }
  }

  dynamic "block_device_mappings" {
    for_each = var.additional_block_device_mappings

    content {
      device_name = try(block_device_mappings.value.device_name, null)

      dynamic "ebs" {
        for_each = try([block_device_mappings.value.ebs], [])

        content {
          delete_on_termination = try(ebs.value.delete_on_termination, null)
          encrypted             = try(ebs.value.encrypted, null)
          iops                  = try(ebs.value.iops, null)
          kms_key_id            = try(ebs.value.kms_key_id, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          throughput            = try(ebs.value.throughput, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }

      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)
    }
  }

  dynamic "metadata_options" {
    for_each = var.metadata_options != {} ? [var.metadata_options] : []
    content {
      http_endpoint               = try(metadata_options.value.http_endpoint, "disabled")
      http_put_response_hop_limit = try(metadata_options.value.http_put_response_hop_limit, 1)
      http_tokens                 = try(metadata_options.value.http_tokens, "optional")
      http_protocol_ipv6          = try(metadata_options.value.http_protocol_ipv6, "disabled")
      instance_metadata_tags      = try(metadata_options.value.instance_metadata_tags, "disabled")
    }
  }
}

