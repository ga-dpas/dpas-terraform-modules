data "aws_ami" "eks_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.eks.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

locals {
  # return first non-empty value
  ami_id = coalesce(var.ami_image_id, data.aws_ami.eks_worker.id)
}

resource "aws_launch_template" "node" {
  name_prefix   = "${var.cluster_id}-node-"
  image_id      = local.ami_id
  instance_type = var.default_worker_instance_type

  user_data = base64encode(templatefile("${path.module}/worker_userdata.tpl.sh",
    {
      cluster_id            = aws_eks_cluster.eks.id
      endpoint              = aws_eks_cluster.eks.endpoint
      certificate_authority = aws_eks_cluster.eks.certificate_authority.0.data

      extra_userdata       = var.extra_userdata
      extra_bootstrap_args = var.extra_bootstrap_args

      enable_imdsv2 = var.metadata_options.http_tokens == "required"
    }
  ))

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

