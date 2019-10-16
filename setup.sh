#!/bin/sh

#
# Author: urain39@qq.com
#

HERE=${0%/*}

NEXTCLOUD_USER="nextcloud"
OS_NAME="alpine-nextcloud"
SERVER_NAME="0.0.0.0"
UPLOAD_LIMIT="8G"
MEMORY_LIMIT="512M"
ARIA2_USER="aria2" # Do NOT modify!


# Load custom config
if [ -f ${HERE}/config.conf ]; then
    . ${HERE}/config.conf
fi


# Install base system
mkdir ${OS_NAME} && cd ${OS_NAME}
wget -O - http://mirrors.aliyun.com/alpine/v3.10/releases/aarch64/alpine-minirootfs-3.10.0-aarch64.tar.gz | tar xzvpf -
cd ../ && alcove init ${OS_NAME} && rm -f ${OS_NAME}/alcove.binds # Old version compatible


# Start install NextCloud
alcove boot ${OS_NAME} <<EOI
umask 0022 # Ensure permission is we want

# Switch to mirror sources
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# Install NextCloud
apk --update --no-cache add \
    aria2 \
    aria2-daemon \
    nextcloud \
    nextcloud-files_external \
    nextcloud-notifications \
    nextcloud-pdfviewer \
    nextcloud-sqlite \
    nextcloud-texteditor \
    nextcloud-videoplayer \
    nginx \
    openrc \
    openssl \
    php7-fpm \
    shadow \
    sudo

# Set for OpenRC(due to chroot)
mkdir -p /run/openrc && touch /run/openrc/softlevel

# Patch for Networking
cat > /etc/init.d/networking <<EOP
#!/bin/sh

# Do nothing, always exit 0
exit 0
EOP


# Fix crash for Aria2-daemon
su - "${ARIA2_USER}" -s /bin/sh -c "
    touch ~/aria2.session
"

# Fix network for Aria2
patch_user "${ARIA2_USER}"

# Fix access for NextCloud
addgroup "${NEXTCLOUD_USER}" "${ARIA2_USER}"

# Register alcove hooks
ln -s /etc/init.d/aria2 /alcove-hooks/80-aria2


# Disable default.conf
mv /etc/nginx/conf.d/default.conf \
   /etc/nginx/conf.d/default.conf.bak

# Setup Web Server
cat > /etc/nginx/conf.d/nextcloud.conf <<EOC
server {
	#listen	   [::]:80; #uncomment for IPv6 support
	listen	   80;
	return 301 https://\\\$host\\\$request_uri;
	server_name ${SERVER_NAME};
}

server {
	#listen	   [::]:443 ssl; #uncomment for IPv6 support
	listen	   443 ssl;
	server_name  ${SERVER_NAME};

	root /usr/share/webapps/nextcloud;
	index  index.php index.html index.htm;
	disable_symlinks off;

	ssl_certificate	  /etc/ssl/certs/nginx-selfsigned.crt;
	ssl_certificate_key  /etc/ssl/private/nginx-selfsigned.key;
	ssl_session_timeout  5m;

	#Enable Perfect Forward Secrecy and ciphers without known vulnerabilities
	#Beware! It breaks compatibility with older OS and browsers (e.g. Windows XP, Android 2.x, etc.)
	#ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA;
	#ssl_prefer_server_ciphers  on;


	location / {
		try_files \\\$uri \\\$uri/ /index.html;
	}

	# pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
	location ~ [^/]\.php(/|\\\$) {
		fastcgi_split_path_info ^(.+?\.php)(/.*)\\\$;

		if (!-f \\\$document_root\\\$fastcgi_script_name) {
			return 404;
		}

		fastcgi_pass 127.0.0.1:9000;
		#fastcgi_pass unix:/run/php-fpm/socket;
		fastcgi_index index.php;
		include fastcgi.conf;
	}
}
EOC

# Generate a self-signed certificate
openssl req -x509 -nodes \
    -days 365 -newkey rsa:4096 -keyout \
    /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt <<EOI2









EOI2

# Re-set nginx user and group
sed -Ei -e 's/^([ \t]*user[ \t]+).+(;.*)$/\1${NEXTCLOUD_USER} www-data\2/g' \
        /etc/nginx/nginx.conf

# Re-set php-fpm user and group
sed -Ei -e 's/^([ \t]*user[ \t]*=[ \t]*).+$/\1${NEXTCLOUD_USER}/g' \
        -e 's/^([ \t]*group[ \t]*=[ \t]*).+$/\1www-data/g' \
        /etc/php7/php-fpm.d/www.conf

# Set max upload size
sed -Ei -e 's/^([ \t]*client_max_body_size[ \t]+).+(;.*)$/\1${UPLOAD_LIMIT}\2/g' \
        /etc/nginx/nginx.conf

# Set max memory size
cat > /etc/php7/conf.d/99-override.ini <<EOC2
memory_limit = ${MEMORY_LIMIT}
EOC2

# Fix cannot upload
chown ${NEXTCLOUD_USER}:www-data /var/tmp/nginx
chown ${NEXTCLOUD_USER}:www-data /var/lib/nginx

group_list() {
cat <<EOF
net_bt_admin:x:3001
net_bt:x:3002
inet:x:3003
net_raw:x:3004
net_admin:x:3005
net_bw_stats:x:3006
net_bw_acct:x:3007
net_bt_stack:x:3008
sdcard_r:x:1028
EOF
}

patch_group() {
    [ -e /etc/group ] || {
        echo "Do not run this script at outside!"
        return 1
    }
    grep -q "net_bt_admin" /etc/group || {
        group_list >> /etc/group
    }
}

patch_user() {
    local user="\${1}"
    [ x\${user} = "x" ] && return
    group_list | while read group; do
        group=\$(echo \${group} | cut -d':' -f1)
        gpasswd -a "\${user}" \${group} || return
    done
}

# Fix network for Nginx
patch_group && patch_user "${NEXTCLOUD_USER}"


# Register alcove hooks
ln -s /etc/init.d/php-fpm7 /alcove-hooks/60-php-fpm7
ln -s /etc/init.d/nginx /alcove-hooks/61-nginx


# Add cron script for Downloaders
cat > /etc/periodic/15min/70-nextcloud-scan <<EOS
#!/bin/sh

# Scan files for Downloaders
occ files:scan --all
EOS

# Mark script executable
chmod 755 /etc/periodic/15min/70-nextcloud-scan


# Trigger OpenRC
openrc


# No login
sed -i 's/^\([ \t]*\)su - root/\1echo "Press Ctrl+C to exit." \&\& crond -f/g' /init.sh
EOI
