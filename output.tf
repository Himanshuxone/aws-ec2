output "subnet_cidr_blocks" {
  value = [for s in data.aws_subnets.default_subnet : s.cidr_block]
}

output "arn1" {
  value = aws_instance.instance_1.arn
}

output "public_ip_1" {
  value = aws_instance.instance_1.public_ip
}

output "arn2" {
  value = aws_instance.instance_2.arn
}

output "public_ip_2" {
  value = aws_instance.instance_2.public_ip
}