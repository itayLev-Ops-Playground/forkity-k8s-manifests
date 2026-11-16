locals {
  instance_names = [
    "jenkins-server",
    "jenkins-node",
    "monitoring-server",
    "kubernetes-master-node",
    "kubernetes-worker-node"
  ]
}

resource "aws_instance" "ec2" {
  count                  = var.ec2-instance-count
  ami                    = data.aws_ami.ubuntu.id
  subnet_id              = aws_subnet.public-subnet[count.index].id
  instance_type          = var.ec2_instance_type[count.index]
  iam_instance_profile   = aws_iam_instance_profile.iam-instance-profile.name
  vpc_security_group_ids = [aws_security_group.default-ec2-sg.id]
  user_data = local.instance_names[count.index] == "jenkins-server" ? join("\n", [
    file("${path.module}/scripts/jenkins-install.sh"),
    file("${path.module}/scripts/docker-install.sh"),
    file("${path.module}/scripts/post-install.sh"),
    file("${path.module}/scripts/install_jenkins_plugins.sh")
  ]) : null

  root_block_device {
    volume_size = var.ec2_volume_size
    volume_type = var.ec2_volume_type
  }

  tags = {
    Name = "${local.org}-${local.project}-${local.env}-${local.instance_names[count.index]}"
    Env  = "${local.env}"
  }
}