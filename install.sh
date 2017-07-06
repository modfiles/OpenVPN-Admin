#!/bin/bash

print_help () {
  echo -e "./install.sh www_basedir user group"
  echo -e "\tbase_dir: The place where the web application will be put in"
  echo -e "\tuser:     User of the web application"
  echo -e "\tgroup:    Group of the web application"
}

# Ensure to be root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Ensure there are enought arguments
if [ "$#" -ne 3 ]; then
  print_help
  exit
fi

# Ensure there are the prerequisites
for i in openvpn mysql php bower node unzip wget sed; do
  which $i > /dev/null
  if [ "$?" -ne 0 ]; then
    echo "Miss $i"
    exit
  fi
done

www=$1
user=$2
group=$3

openvpn_admin="$www/openvpn-admin"

# Check the validity of the arguments
if [ ! -d "$www" ] ||  ! grep -q "$user" "/etc/passwd" || ! grep -q "$group" "/etc/group" ; then
  print_help
  exit
fi

base_path=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


printf "\n################## Server informations ##################\n"

read -p "Server Hostname/IP: " ip_server

read -p "Port [443]: " server_port

if [[ -z $server_port ]]; then
  server_port="443"
fi

# Get root pass (to create the database and the user)
mysql_root_pass=""
status_code=1

while [ $status_code -ne 0 ]; do
  read -p "MySQL root password: " -s mysql_root_pass; echo
  echo "SHOW DATABASES" | mysql -u root --password="$mysql_root_pass" &> /dev/null
  status_code=$?
done

sql_result=$(echo "SHOW DATABASES" | mysql -u root --password="$mysql_root_pass" | grep -e "^openvpn-admin$")
# Check if the database doesn't already exist
if [ "$sql_result" != "" ]; then
  echo "The openvpn-admin database already exists."
  exit
fi


# Check if the user doesn't already exist
read -p "MySQL user name for OpenVPN-Admin (will be created): " mysql_user

echo "SHOW GRANTS FOR $mysql_user@localhost" | mysql -u root --password="$mysql_root_pass" &> /dev/null
if [ $? -eq 0 ]; then
  echo "The MySQL user already exists."
  exit
fi

read -p "MySQL user password for OpenVPN-Admin: " -s mysql_pass; echo

# TODO MySQL port & host ?

printf "\n################## Setup MySQL database ##################\n"

echo "CREATE DATABASE \`openvpn-admin\`" | mysql -u root --password="$mysql_root_pass"
echo "CREATE USER $mysql_user@localhost IDENTIFIED BY '$mysql_pass'" | mysql -u root --password="$mysql_root_pass"
echo "GRANT ALL PRIVILEGES ON \`openvpn-admin\`.*  TO $mysql_user@localhost" | mysql -u root --password="$mysql_root_pass"
echo "FLUSH PRIVILEGES" | mysql -u root --password="$mysql_root_pass"


printf "\n################## Setup web application ##################\n"

# Copy bash scripts (which will insert row in MySQL)
cp -r "$base_path/installation/scripts" "/etc/openvpn/"
chmod +x "/etc/openvpn/scripts/"*

# Configure MySQL in openvpn scripts
sed -i "s/USER=''/USER='$mysql_user'/" "/etc/openvpn/scripts/config.sh"
sed -i "s/PASS=''/PASS='$mysql_pass'/" "/etc/openvpn/scripts/config.sh"

# Create the directory of the web application
mkdir "$openvpn_admin"
cp -r "$base_path/"{index.php,sql,bower.json,.bowerrc,js,include,css,installation/client-conf} "$openvpn_admin"

# New workspace
cd "$openvpn_admin"

# Replace config.php variables
sed -i "s/\$user = '';/\$user = '$mysql_user';/" "./include/config.php"
sed -i "s/\$pass = '';/\$pass = '$mysql_pass';/" "./include/config.php"

# Replace in the client configurations with the ip of the server
sed -i "s/remote xxx\.xxx\.xxx\.xxx 1125/remote $ip_server $server_port/" "./client-conf/gnu-linux/client.conf"
sed -i "s/remote xxx\.xxx\.xxx\.xxx 1125/remote $ip_server $server_port/" "./client-conf/android/client.conf"
sed -i "s/remote xxx\.xxx\.xxx\.xxx 1125/remote $ip_server $server_port/" "./client-conf/ios/client.conf"
sed -i "s/remote xxx\.xxx\.xxx\.xxx 1125/remote $ip_server $server_port/" "./client-conf/windows/client.ovpn"
sed -i "s/remote xxx\.xxx\.xxx\.xxx 1125/remote $ip_server $server_port/" "./client-conf/osx-viscosity/client.conf"

# Replace in the client configurations proxy with the ip of the server
sed -i "s/http-proxy xxx\.xxx\.xxx\.xxx 3128/remote $ip_server $server_port/" "./client-conf/gnu-linux/client.conf"
sed -i "s/http-proxy xxx\.xxx\.xxx\.xxx 3128/remote $ip_server $server_port/" "./client-conf/android/client.conf"
sed -i "s/http-proxy xxx\.xxx\.xxx\.xxx 3128/remote $ip_server $server_port/" "./client-conf/ios/client.conf"
sed -i "s/http-proxy xxx\.xxx\.xxx\.xxx 3128/remote $ip_server $server_port/" "./client-conf/windows/client.ovpn"
sed -i "s/http-proxy xxx\.xxx\.xxx\.xxx 3128/remote $ip_server $server_port/" "./client-conf/osx-viscosity/client.conf"

# Copy ta.key inside the client-conf directory
cp "/etc/openvpn/"{ca.crt,ta.key} "./client-conf/gnu-linux/"
cp "/etc/openvpn/"{ca.crt,ta.key} "./client-conf/windows/"
cp "/etc/openvpn/"{ca.crt,ta.key} "./client-conf/android/"
cp "/etc/openvpn/"{ca.crt,ta.key} "./client-conf/ios/"
cp "/etc/openvpn/"{ca.crt,ta.key} "./client-conf/osx-viscosity/"

# Install third parties
bower --allow-root install
chown -R "$user:$group" "$openvpn_admin"

printf "\033[1m\n#################################### Finish ####################################\n"

echo -e "# Congratulations, you have successfully setup OpenVPN-Admin! #\r"
echo -e "Please, finish the installation by configuring your web server (Apache, NGinx...)"
echo -e "and install the web application by visiting http://your-installation/index.php?installation\r"
echo -e "Then, you will be able to run OpenVPN with systemctl start openvpn@server\r"
echo "Please, report any issues here https://github.com/modfiles/OpenVPN-Admin"
printf "\n################################################################################ \033[0m\n"
