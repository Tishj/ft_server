#Install the base image for Debian Buster, the OS we'll be running the container in.

FROM debian:buster

#Expose the port 80 for HTTP
#Expose the port 443 for HTTPS

EXPOSE 80 443
WORKDIR /root/

#Install every piece of our modified LEMP stack we'll need.

RUN apt-get -y update && \
	apt-get -y upgrade && \
	apt-get -y install \
	mariadb-server \
	mariadb-client \
	unzip \
	wget \
	php \
	sudo \
	sendmail \
	php-cli \
	php-cgi \
	php7.3-zip \
	php-json \
	php-mbstring \
	php-fpm \
	php-mysql \
	nginx \
	libnss3-tools

#Configuring PHPMyAdmin

RUN		mkdir -p /var/www/html/wordpress
COPY	/srcs/phpMyAdmin-4.9+snapshot-all-languages.tar.gz /tmp/
RUN		tar -zxvf /tmp/phpMyAdmin-4.9+snapshot-all-languages.tar.gz -C /tmp
RUN		cp -r /tmp/phpMyAdmin-4.9+snapshot-all-languages/. \
		/var/www/html/wordpress/phpmyadmin
RUN		chmod a+rwx,g-w,o-w /var/www/html/wordpress/phpmyadmin/tmp
COPY	/srcs/config.inc.php /var/www/html/wordpress/phpmyadmin

#This line is necessarry for me at home (Windows) to prevent an error in phpmyadmin
#It would say that phpmyadmin config is modifiable by world

#RUN		chmod a+rwx,g-w,o-w /var/www/html/wordpress/phpmyadmin/config.inc.php

#Creating the mysql database for Wordpress

RUN		service mysql start && \
		mysql -e "CREATE DATABASE wordpress_db;" && \	
		mysql -e "CREATE USER 'admin'@'localhost' IDENTIFIED BY 'admin';" && \
		mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;" && \
		mysql -e "FLUSH PRIVILEGES;"

#Copy the Wordpress-CLI files and update it,
#there has to be a database first.

COPY	/srcs/wp-cli.phar /tmp/
RUN		chmod a+rwx,g-w,o-w /tmp/wp-cli.phar
RUN		mv /tmp/wp-cli.phar /usr/local/bin/wp
RUN		wp cli update

#Configuring super-user

RUN		adduser --disabled-password --gecos "" admin
RUN		sudo adduser admin sudo

#Configure the Wordpress CLI.
#Add all the data of the database (tables, user, etc..) to the phpmyadmin config
#Make the www-data group owner of the files, Nginx will act as this group to carry out operations.

RUN		service mysql start && sudo -u admin -i wp core download && \
		mysql < /var/www/html/wordpress/phpmyadmin/sql/create_tables.sql && \
		sudo -u admin -i wp core config --dbname=wordpress_db --dbuser=admin --dbpass=admin && \
		sudo -u admin -i wp core install --url=https://localhost/ --title=WordPress \
		--admin_user=admin --admin_password=admin --admin_email=admin@gmail.com
RUN		cp -r /home/admin/. /var/www/html/wordpress
RUN		chown -R www-data:www-data /var/www/html/*

#Copying all the required files from srcs/

COPY	/srcs/localhost.cert /etc/ssl/certs/server.cert
COPY	/srcs/localhost.key /etc/ssl/private/server.key
COPY	/srcs/server.conf /etc/nginx/sites-available/server.conf
COPY	/srcs/switch_index.sh /
RUN		chmod +x /switch_index.sh
RUN		ln -s /etc/nginx/sites-available/server.conf /etc/nginx/sites-enabled/server.conf
RUN		rm -rf /etc/nginx/sites-enabled/default

#Increase the maximum upload size in the php.ini

RUN		sed -i '/upload_max_filesize/c upload_max_filesize = 20M' /etc/php/7.3/fpm/php.ini
RUN		sed -i '/post_max_size/c post_max_size = 21M' /etc/php/7.3/fpm/php.ini

#Start all the services when starting our image

CMD		service nginx restart && \
		service mysql start && \
		service php7.3-fpm start && \
		echo "127.0.0.1 localhost localhost.localdomain $(hostname)" >> /etc/hosts && \
		service sendmail start && \
		bash
