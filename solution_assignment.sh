#!/bin/bash
LOG_FILE="`mktemp`"
LINUX_DISTRO="`lsb_release -i | cut -d':' -f2 | awk '{print $1}'`"
WORDPRESS_ZIP="`mktemp`.tar.gz"
WORDPRESS_UNZIP_DIR="`mktemp -d`"
if [ $LINUX_DISTRO != "Ubuntu" ] && [ $LINUX_DISTRO != "Debian" ];then
	echo "This scripts is created to Work on Ubuntu or Debian" 
	echo "Quiting..." 
	exit 1
fi 

if [[ $EUID -ne 0 ]]; then

	echo "This script must be run as root" 
	echo "Use sudo ./solution.sh to run this script" 
	exit 1
fi
touch $LOG_FILE
chmod 777 $LOG_FILE
clear
echo ""
echo "--------------------------------------------------------------------------"
echo "	Ngnix, MySQL and PHP5 for latest version of WordPress"
echo "	This scripts also writes log to file $LOG_FILE"
echo "--------------------------------------------------------------------------"

echo ""
echo ""
echo "Now We are going to install Nagix,MysQL server and PHP5"
echo ""
echo "	Ngnix, MySQL Server & PHP5 Installation..."
echo ""
echo "	Updating Package List..."
apt-get update >> $LOG_FILE 
if [[ $? -ne 0 ]]; then
	echo "ERROR: Failed to update Package List, Please check logfile $LOG_FILE" 1>&2 
	exit 1
fi
echo "Checking For Installed Nginx..."
dpkg-query -s nginx >> $LOG_FILE  
if [[ $? -ne 0 ]]; then 
echo "Failed to Found Nginx,Please Wait Installing Nginx..."
apt-get -y install nginx >> $LOG_FILE
	if [[ $? -ne 0 ]]; then
		echo "ERROR: Failed to install Nginx, Please check logfile $LOG_FILE"1>&2
		exit 1
	fi
		
else
	echo "Found Nginx Installation,Skipping Installation"
fi

echo "Checking for Installed MySQL"
dpkg-query -s mysql-server >> $LOG_FILE
if [[ $? -ne 0 ]]; then
	echo "Failed to Found MySQL,Please Wait Installing MySQL..."
	debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
	debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
 	apt-get -y install mysql-server >> $LOG_FILE
	if [[ $? -ne 0 ]];then
		echo "Failed to install Mysql ,Please Check Error Log $LOG_FILE" 1>&2
		exit 1
	fi
else 
	echo "Found MySQL Installation,Skipping Installation..."
fi
echo "Checking for Installed php5"
dpkg-query -s php5 >> $LOG_FILE
if [[ $? -ne 0 ]]; then
	echo "Failed to Found PHP5,please wait Installing.."
	apt-get -y install php5 php5-mysql
	if [[ $? -ne 0 ]]; then
		echo "Please check log unableto install php5 $LOG_FILE"1>&2
		exit 1
	fi
else 
	echo "Found php5 ,skipping installation"
fi

echo "Checking for Installed php5-fpm"
dpkg-query -s php5-fpm >> $LOG_FILE
if [[ $? -ne 0 ]];then
	echo "Failed to found php5-fpm ,Please Wait Installing php5-fpm"
	apt-get -y install php5-fpm
	if [$? -ne 0 ];then
		echo "Unable to install php5-fmp ,Please Check log $LOG_FILE"1>&2
		exit 1
	fi
else 
	echo "Found php5-fpm,Skipping Installation"
fi

echo -n "Enter Domain name: "
read Domain_name
echo "Domain name is $Domain_name"
while [[ -z $Domain_name ]]; do
	echo "Domain name must not be null,Enter Domain name "
	read Domain_name
done

if [[ -d "/var/www/$Domain_name" ]];then
	echo "Error:Domain name is already exist"
	exit 1
fi
echo "127.0.0.1 $Domain_name" >> /etc/hosts

cat <<EOF> /etc/nginx/sites-available/$Domain_name
server {
        listen   80;
        root /var/www/$Domain_name;
        index index.php index.html index.htm;
        server_name "$Domain_name";
        location / {
                try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
        }
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
              root /usr/share/nginx/www;
        }
        location ~ \.php$ {
                try_files \$uri =404;
                fastcgi_pass unix:/var/run/php5-fpm.sock;
                fastcgi_index index.php;
                include fastcgi_params;
                 }
        

}
EOF
ln -sf /etc/nginx/sites-available/$Domain_name /etc/nginx/sites-enabled/$Domain_name
service nginx restart >> $LOG_FILE 2>&1 
service php5-fpm restart >> $LOG_FILE 2>&1 
echo "" 
echo " "


echo "	Wait while downloading Wordpress from http://wordpress.org/latest.tar.gz..."
wget -O $WORDPRESS_ZIP -q http://wordpress.org/latest.tar.gz >> $LOG_FILE 2>&1 
if [ $? -ne 0 ];then
	echo "ERROR: Failed to get file http://wordpress.org/latest.tar.gz, Please check logfile $LOG_FILE" 1>&2
	exit 1
fi
type tar >> $LOG_FILE 2>&1 

if [ $? -ne 0 ];then
	apt-get install tar >> $LOG_FILE 2>&1
	if [ $? -ne 0 ];then
		echo "ERROR: Failed to install TAR utility, Please check logfile $LOG_FILE" 1>&2
		exit 1
	fi
fi
	
cd $WORDPRESS_UNZIP_DIR
tar -xvf $WORDPRESS_ZIP >> $LOG_FILE 2>&1 
cd - >> $LOG_FILE 2>&1 

if [ $? -ne 0 ];then
	echo "ERROR: Failed to unzip latest.tar.gz, Please check logfile $LOG_FILE" 1>&2
	exit 1
fi

echo ""
echo ""

echo "Step -4 Completed. Unzipping Successfull"

echo ""
echo ""

echo "Step -5:"
echo ""
echo "	Configuring WordPress..."


mkdir -p /var/www/$DOMAIN_NAME
if [ $? -ne 0 ];then
	echo "ERROR: Failed to Create Directory /var/www/$DOMAIN_NAME, Please check logfile $LOG_FILE" 1>&2
	exit 1
fi
cp -rf $WORDPRESS_UNZIP_DIR/wordpress/* /var/www/$DOMAIN_NAME
if [ $? -ne 0 ];then
	echo "ERROR: Failed to copy $WORDPRESS_UNZIP_DIR/wordpress/* to /var/www/$DOMAIN_NAME, Please check logfile $LOG_FILE" 1>&2
	exit 1
fi


sed "s/username_here/wordpressuser/" /var/www/$DOMAIN_NAME/wp-config-sample.php > /var/www/$DOMAIN_NAME/wp-config1.php
sed "s/database_name_here/$DOMAIN_NAME$DB_EXT/" /var/www/$DOMAIN_NAME/wp-config1.php > /var/www/$DOMAIN_NAME/wp-config2.php
sed "s/password_here/password/" /var/www/$DOMAIN_NAME/wp-config2.php > /var/www/$DOMAIN_NAME/wp-config3.php
mv /var/www/$DOMAIN_NAME/wp-config3.php /var/www/$DOMAIN_NAME/wp-config.php

SALT=$(curl -s -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s /var/www/$DOMAIN_NAME/wp-config.php

chown -R www-data:www-data /var/www/$DOMAIN_NAME
if [ $? -ne 0 ];then
	echo "ERROR: Failed to Ownership of www-data:www-data /var/www/$DOMAIN_NAME, Please check logfile $LOG_FILE" 1>&2
	exit 1
fi
chmod -R 755 /var/www
echo ""
echo ""
echo "Step -5 Completed. Configuration Successfull"
echo ""
echo ""
echo "Step -6:"
echo ""
echo ""
echo "	Creating MySQL database..."

mysql --user=root --password=$DB_ROOT_PASS --execute="CREATE DATABASE IF NOT EXISTS \`$DOMAIN_NAME$DB_EXT\`; grant all on \`$DOMAIN_NAME$DB_EXT\`.* to 'wordpressuser'@'localhost' identified by 'password'; FLUSH PRIVILEGES;" >> $LOG_FILE 2>&1 

if [ $? -ne 0 ];then
	echo "ERROR: Failed to Create Database, Please check logfile $LOG_FILE" 1>&2
	exit 1
fi

echo ""
echo ""
echo "Step -6 Completed."

rm $WORDPRESS_ZIP
rm -rf $WORDPRES_UNZIP_DIR
rm -rf /var/www/$DOMAIN_NAME/wp-config1.php /var/www/$DOMAIN_NAME/wp-config2.php


echo ""
echo ""
echo "Script Executed Successfully." 
echo "Please open http://$DOMAIN_NAME in your faviourate browser to access your WordPress Site."
echo "Installtion Log are availble at file $LOG_FILE"
exit 0;
