#!/bin/bash
# This block defines the variables the user of the script needs to input
# when deploying using this script.
#

output "Enter your SetSeed license activation code here. SetSeed will not install without this being valid. Entering your activation code here represents your acceptance of our EULA available at http://setseed.com/eula/"
read -p "ACTIVATIONCODE : " ACTIVATIONCODE
#
output "Fully Qualified Domain Name. This will also be your SetSeed Hub primary domain. Use a subdomain like app.example.com - all websites you create with SetSeed will then use this domain as a preview domain. For example, if you created a site with the domain of www.setseed.com and your primary domain is app.example.com, the site would be visible on www.setseed.com as well as www.setseed.com.app.example.com"
read -p "Enter servername (e.g. app.example.com) : " FQDN
#
output "MySQL root password"
read -p "Enter MySQL Root Password : " DB_ROOT_PASSWORD
#
output "MySQL password for setseed_master user account"
read -p "Enter MySQL setseed_master Password : " DB_SETSEED_MASTER_PASSWORD
#
output "SMTP sending server. This is used to ensure outbound email from the server is routed via a proper SMTP server. Recommended SMTP providers: mailgun.org or sendgrid.com"
read -p "Enter SMTP Server : " SMTP_SERVER
#
output "SMTP sending server username"
read -p "Enter SMTP User : " SMTP_USER
#
output "SMTP sending server password"
read -p "Enter SMTP Password : " SMTP_PASS
#


exec >/root/stdout.txt
output "Starting Script"

# This updates the packages on the system from the distribution repositories.
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y autoremove
sudo apt-get -y install aptitude
sudo apt-get -y install net-tools
sudo apt-get -y install exim4
sudo apt-get -y install software-properties-common
whoami=`whoami`

# This sets the variable $IPADDR to the IP address the new Linode receives.
IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')

# This section sets the Fully Qualified Domain Name (FQDN) in the hosts file.
echo $IPADDR $FQDN >> /etc/hosts

# Install Apache
sudo aptitude -y install apache2
# Disable default and add SetSeed Virtual Host
sudo a2dissite 000-default

echo '<VirtualHost *:80>
    ServerName '"${FQDN}"';
    DocumentRoot /var/www/html/
    <Directory /var/www/>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
    </Directory>
</VirtualHost>
' | sudo -E tee /etc/apache2/sites-available/setseed.conf >/dev/null 2>&1

sudo a2ensite setseed

echo '<!doctype html>
<html lang=\ "\">

<head>
    <meta charset=\ "utf-8\">
    <meta http-equiv=\ "X-UA-Compatible\" content=\ "IE=edge,chrome=1\">
    <title>Installing.. Please Wait.</title>
    <link rel=\ "stylesheet\" href=\ "https://secure.setseed.com/static/css/style.css?v19\" type=\ "text/css\" media=\ "screen\" />
    <script src=\ "https://secure.setseed.com/static/js/jquery.js\" type=\ "text/javascript\" charset=\ "utf-8\"></script>
    <script type=\ "text/javascript\">
        \
        $(document).ready(function() {
                    function test() {\
                        $.ajax({
                                    cache: false,
                                    url: \ "/sh/\",                      success: function (data) {                          window.location.href=\"/sh/?installsuccess=1\";                         },                      error: function (ajaxContext) {                             setTimeout(function () {                                test();                             }, 2000);                       }                   });                 }               setTimeout(function () {                    test();                 }, 2000);           });
    </script>
    <style type=\ "text/css\" media=\ "screen\">
        #middle {
            position: absolute;
            top: 50%;
            left: 0;
            width: 100%;
            transform: translateY(-50%);
        }
        
        .spinner {
            width: 40px;
            height: 40px;
            margin: 40px auto;
            background-color: #333;
            border-radius: 100%;
            -webkit-animation: sk-scaleout 1.0s infinite ease-in-out;
            animation: sk-scaleout 1.0s infinite ease-in-out;
        }
        
        @-webkit-keyframes sk-scaleout {
            0% {
                -webkit-transform: scale(0)
            }
            100% {
                -webkit-transform: scale(1.0);
                opacity: 0;
            }
        }
        
        @keyframes sk-scaleout {
            0% {
                -webkit-transform: scale(0);
                transform: scale(0);
            }
            100% {
                -webkit-transform: scale(1.0);
                transform: scale(1.0);
                opacity: 0;
            }
        }
    </style>
</head>

<body style=\ "background:#fff\">
    <div id=\ "middle\">
        <p style='text-align:center'><img src=\ "http://setseed.com/graphics/setseed-logo-for-email.png\" width=\ "144\" height=\ "67\"/></p>
        <p style=\ "text-align:center;font-size:14px;color:#888\">Installing... Please Wait.</p>
        <div class=\ "spinner\"></div>
    </div>
</body>

</html>
' | sudo -E tee /var/www/html/index.html >/dev/null 2>&1


# Install MySQL
echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections

sudo aptitude -y install mariadb-server mariadb-client >> /root/mysqlinstall.txt 2>&1

echo "MYSQL Installed successfully"
sudo mysql -u root -proot -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_ROOT_PASSWORD'); flush privileges;" >> /root/mysqlinstall.txt 2>&1
echo "MYSQL Root pass successfully changed to $DB_ROOT_PASSWORD"
sudo mysql -u root -p$DB_ROOT_PASSWORD -e "CREATE DATABASE setseed_master DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci; CREATE USER 'setseed_master'@'localhost' IDENTIFIED BY '$DB_SETSEED_MASTER_PASSWORD'; GRANT ALL PRIVILEGES ON *.* TO 'setseed_master'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES; USE setseed_master; CREATE TABLE \`email_campaigns\` (   \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,   \`hash\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`content\` mediumtext COLLATE latin1_general_ci NOT NULL,   \`subject\` text COLLATE latin1_general_ci NOT NULL,   \`server_name\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`from_name\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`from_email\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`smtp_server\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`username\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`password\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`belongs_to_site\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`webversion\` varchar(255) COLLATE latin1_general_ci NOT NULL DEFAULT '',   \`complete\` int(11) NOT NULL,   \`failed\` int(11) NOT NULL,   \`date_created\` datetime NOT NULL,   \`cancelled\` int(11) NOT NULL,   PRIMARY KEY (\`id\`) ) ENGINE=InnoDB AUTO_INCREMENT=128 DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci; CREATE TABLE \`email_queue\` (   \`id\` int(11) unsigned NOT NULL AUTO_INCREMENT,   \`campaign_id\` int(11) NOT NULL,   \`email\` varchar(255) NOT NULL DEFAULT '',   \`first_name\` varchar(255) NOT NULL DEFAULT '',   \`last_name\` varchar(255) NOT NULL DEFAULT '',   \`pending\` int(11) NOT NULL,   \`newsletter_email_id\` int(11) NOT NULL,   \`sent\` int(11) NOT NULL,   \`seen\` int(11) NOT NULL,   \`unsubscribe\` int(11) NOT NULL,   \`failed\` int(11) NOT NULL,   PRIMARY KEY (\`id\`),   KEY \`campaign_id\` (\`campaign_id\`),   KEY \`campaign_id_2\` (\`campaign_id\`,\`sent\`),   KEY \`campaign_id_3\` (\`campaign_id\`,\`seen\`),   KEY \`campaign_id_4\` (\`campaign_id\`,\`unsubscribe\`),   KEY \`campaign_id_5\` (\`campaign_id\`,\`failed\`) ) ENGINE=InnoDB AUTO_INCREMENT=80018 DEFAULT CHARSET=latin1; CREATE TABLE sites (url mediumtext NOT NULL,invisible_key varchar(255) NOT NULL,theme varchar(255) NOT NULL DEFAULT 'default',db_username varchar(255) NOT NULL,db_password varchar(255) NOT NULL,db_name varchar(255) NOT NULL,db_host varchar(255) NOT NULL,branding_name varchar(255) NOT NULL,branding_key varchar(255) NOT NULL,branding_logo_light text NOT NULL,  branding_logo_dark text NOT NULL,branding_favicon text NOT NULL,UNIQUE KEY url (url(300))) ENGINE=MyISAM DEFAULT CHARSET=latin1; CREATE TABLE admin (username varchar(255) NOT NULL,password char(40) NOT NULL,salt varchar(255) NOT NULL,logged_in_key VARCHAR(255) NOT NULL,age VARCHAR(255) NOT NULL,uaip VARCHAR(255) NOT NULL) ENGINE=MyISAM DEFAULT CHARSET=latin1;" >> /root/mysqlinstall.txt 2>&1
echo "setseed_master created with user pass as $DB_SETSEED_MASTER_PASSWORD and initial tables created"

# Install PHP
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo aptitude -y install php5.6 libapache2-mod-php5.6 php5.6-curl php5.6-gd php5.6-mbstring php5.6-mcrypt php5.6-mysql php5.6-xml


# Enable some mods
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod expires

# Install IonCube
MODULES=$(php -i | grep extension_dir | awk '{print $NF}')
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
sudo wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
sudo tar xvfz ioncube_loaders_lin_x86-64.tar.gz
sudo cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" $MODULES
echo "zend_extension = $MODULES/ioncube_loader_lin_${PHP_VERSION}.so" >> /etc/php/5.6/apache2/php.ini 
echo "zend_extension = $MODULES/ioncube_loader_lin_${PHP_VERSION}.so" >> /etc/php/5.6/cli/php.ini 
# Restart Apache for changes to take effect
sudo systemctl restart apache2

# Install SetSeed
sudo wget -O download.tgz https://secure.setseed.com/main/download_tgz/?c=$ACTIVATIONCODE 
sudo rm -rf /var/www/html
sudo tar -xvzf download.tgz -C /var/www/
sudo mv /var/www/* /var/www/html
chmod 777 /var/www/html/sites
cp -rp /var/www/html/install/default /var/www/html/sites/.
chmod 777 /var/www/html/sites/default/cache
chmod 777 /var/www/html/sites/default/cache/cache
chmod 777 /var/www/html/sites/default/cache/templates_c
chmod 777 /var/www/html/sites/default/cache/configs
chmod 777 /var/www/html/sites/default/downloads
chmod 777 /var/www/html/sites/default/email_attachments
chmod 777 /var/www/html/sites/default/images
chmod 777 /var/www/html/sites/default/images/galleries
chmod 777 /var/www/html/sites/default/livechatlogs
chmod 777 /var/www/html/sites/default/livechatsaves
chmod 777 /var/www/html/sites/default/media

chmod 777 /var/www/html/sites/customer_signup/cache
chmod 777 /var/www/html/sites/customer_signup/cache/cache
chmod 777 /var/www/html/sites/customer_signup/cache/templates_c
chmod 777 /var/www/html/sites/customer_signup/cache/configs
chmod 777 /var/www/html/sites/customer_signup/downloads
chmod 777 /var/www/html/sites/customer_signup/email_attachments
chmod 777 /var/www/html/sites/customer_signup/images
chmod 777 /var/www/html/sites/customer_signup/images/galleries
chmod 777 /var/www/html/sites/customer_signup/images/thumbs
chmod 777 /var/www/html/sites/customer_signup/livechatlogs
chmod 777 /var/www/html/sites/customer_signup/livechatsaves
chmod 777 /var/www/html/sites/customer_signup/media

sudo rm -rf /var/www/html/install
sudo mv /var/www/html/rename-during-install.htaccess /var/www/html/.htaccess
sudo rm /var/www/html/app/configuration.php

echo '<?php
/*
  Enter the MySQL connection information for your primary SetSeed database below:
*/
$mysql_database = setseed_master;
$mysql_username = setseed_master;
$mysql_password = '"${DB_SETSEED_MASTER_PASSWORD}"';
$mysql_server = localhost;

/*
  Enter the primary domain for this server. This can be a generic domain or subdomain that you use to identify and view this server. Enter it without http:// and ithout a trailing slash.
*/
$primaryDomain = '"${FQDN}"';

// Do not edit below this line //////////////////////////////////////////////////////////////////////////////////////////
$rootdir = dirname(dirname(__FILE__));define( 'ROOT_DIR', \$rootdir );if (!isset(\$installer)) { require_once \"boot.php\"; }
?>
' | sudo -E tee /var/www/html/app/configuration.php >/dev/null 2>&1

sudo mkdir /var/www/html/app/cache/cache
sudo mkdir /var/www/html/app/cache/configs
sudo mkdir /var/www/html/app/cache/templates_c

chmod 777 /var/www/html/app/cache
chmod 777 /var/www/html/app/cache/cache
chmod 777 /var/www/html/app/cache/configs
chmod 777 /var/www/html/app/cache/templates_c
chmod 777 /var/www/html/admin/css/css_archives
chmod 777 /var/www/html/admin/javascripts/js_archives
chmod 777 /var/www/html/admin/javascripts/js_archives2

echo 'dc_eximconfig_configtype='satellite'
dc_other_hostnames=''
dc_local_interfaces='127.0.0.1'
dc_readhost=''
dc_relay_domains=''
dc_minimaldns='false'
dc_relay_nets=''
dc_smarthost='$SMTP_SERVER::587'
CFILEMODE='644'
dc_use_split_config='false'
dc_hide_mailname='true'
dc_mailname_in_oh='true'
dc_localdelivery='mail_spool'
' | sudo -E tee /etc/exim4/update-exim4.conf.conf >/dev/null 2>&1

echo "$SMTP_SERVER:$SMTP_USER:$SMTP_PASS" >> /etc/exim4/passwd.client

sudo systemctl restart exim4

echo "*/1 * * * * php \"/var/www/html/sh/email-queue-send.php\" > \"/var/www/html/sh/mailinglist.log\"" > tempct
crontab tempct
rm tempct
