# Creating DB Subnet Group
resource "aws_db_subnet_group" "RDS_subnet_groups" {
  name       = "rds-subnet-group1"
  subnet_ids = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id, aws_subnet.private_rds1.id]

  tags = {
    Name = "RDS Subnet Group1"
  }
}

resource "aws_rds_cluster" "auroracluster" {
  cluster_identifier = "aurora-cluster1"
  engine             = "aurora-mysql"
  engine_version     = "8.0"
  availability_zones = [var.availability_zone_1, var.availability_zone_2]

  lifecycle {
    ignore_changes = [engine_version]
  }

  database_name   = "aurora_mywordpressdb"
  master_username = "Ciyan"
  master_password = "Deham1eM3n3Z"

  skip_final_snapshot       = true
  final_snapshot_identifier = "my-final-snapshot1"

  db_subnet_group_name   = aws_db_subnet_group.RDS_subnet_groups.name
  vpc_security_group_ids = [aws_security_group.my_sg.id]

  tags = {
    Name = "auroracluster-db"
  }
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "aurora_cluster_instances" {
  count              = 2
  cluster_identifier = aws_rds_cluster.auroracluster.id
  instance_class     = "db.t3.medium"
  engine             = "aurora-mysql"
  availability_zone  = count.index == 0 ? var.availability_zone_1 : var.availability_zone_2

  tags = {
    Name = "aurora-cluster-instance-${count.index}"
  }
}
