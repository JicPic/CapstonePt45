# Capstone45

Scalable and Fault-tolerant WordPress Deployment on AWS

a robust solution for deploying a scalable and fault-tolerant WordPress site on AWS using Terraform, Git, and GitHub. The architecture features a Virtual Private Cloud (VPC) with two private and two public subnets across multiple Availability Zones for redundancy. WordPress is hosted on EC2 instances within an Auto Scaling Group (ASG) that scales between 2 to 4 instances based on CPU utilization. An Application Load Balancer (ALB) ensures even traffic distribution and high availability. The setup includes a NAT Gateway for secure internet access from private subnets and a Bastion Host for secure SSH access. The WordPress site uses an Amazon RDS Aurora MySQL database in private subnets for enhanced security. Simple Notification Service (SNS) notifications monitor instance health and scaling activities, ensuring a resilient and manageable infrastructure.
