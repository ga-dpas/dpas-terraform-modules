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

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform locals here to simplify Base64 encoding this
# information into the AutoScaling Launch Template.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
data "template_file" "node_userdata" {
  template = file("${path.module}/worker_userdata.tpl.sh")
  vars = {
    cluster_id            = aws_eks_cluster.eks.id
    endpoint              = aws_eks_cluster.eks.endpoint
    certificate_authority = aws_eks_cluster.eks.certificate_authority.0.data

    extra_userdata       = var.extra_userdata
    extra_kubelet_args   = var.extra_kubelet_args
    extra_bootstrap_args = var.extra_bootstrap_args
    extra_node_labels    = var.extra_node_labels
  }
}

resource "aws_launch_template" "node" {
  name_prefix   = "${var.cluster_id}-node-"
  image_id      = local.ami_id
  user_data     = base64encode(data.template_file.node_userdata.rendered)
  instance_type = var.default_worker_instance_type

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
}

