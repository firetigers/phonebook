output "dns-name" {
    value = "http://${aws_alb.app-lb.dns_name}"
}

output "websiteurl" {
    value = aws_route53_record.phonebook.name
}