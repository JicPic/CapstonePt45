#! /bin/bash
# Install updates
sudo yum update -y
# Install Apache server
sudo yum install -y httpd
# Install MariaDB, PHP and necessary tools
sudo yum install -y mariadb105-server php php-mysqlnd unzip

# Set database variables

DBName='Ciyan_wp_db'
DBUser='Ciyan'
DBPassword='YOUR DB PASSWORD'
DBRootPassword='YOUR DB ROOT PASSWORD'

# Start Apache server and enable it on system startup
sudo systemctl start httpd
sudo systemctl enable httpd
# Start MariaDB service and enable it on system startup
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Set Mariadb root password
sudo mysqladmin -u root password $DBRootPassword

# Download and install Wordpress
wget http://wordpress.org/latest.tar.gz -P /var/www/html
cd /var/www/html
tar -zxvf latest.tar.gz 
cp -rvf wordpress/* . 
rm -R wordpress 
rm latest.tar.gz

# Configure Wordpress

# Making changes to the wp-config.php file, setting the DB name
cp ./wp-config-sample.php ./wp-config.php # rename the file from sample to clean
sed -i "s/'database_name_here'/'$DBName'/g" wp-config.php 
sed -i "s/'username_here'/'$DBUser'/g" wp-config.php 
sed -i "s/'password_here'/'$DBPassword'/g" wp-config.php

# Grant permissions
sudo usermod -a -G apache ec2-user 
sudo chown -R ec2-user:apache /var/www 
sudo chmod 2775 /var/www 
sudo find /var/www -type d -exec chmod 2775 {} \; 
sudo find /var/www -type f -exec chmod 0664 {} \; 

# Create Wordpress database
echo "CREATE DATABASE $DBName;" >> /tmp/db.setup 
echo "CREATE USER '$DBUser'@'localhost' IDENTIFIED BY '$DBPassword';" >> /tmp/db.setup 
echo "GRANT ALL ON $DBName.* TO '$DBUser'@'localhost';" >> /tmp/db.setup 
echo "FLUSH PRIVILEGES;" >> /tmp/db.setup 
sudo mysql -u root --password=$DBRootPassword < /tmp/db.setup
sudo rm /tmp/db.setup

# Restart Apache
sudo systemctl restart httpd

# Verify services are running
sudo systemctl status httpd
sudo systemctl status mariadb
