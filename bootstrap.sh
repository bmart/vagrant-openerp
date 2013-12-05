#!/usr/bin/env bash

# Script Name : bootstrap.sh

# Runtime:  Vagrant bootstrap script

# Purpose: To initialize an ubuntu server with packages and configuration to
#          assist a developer in working with the OpenERP server.

##################################################################################
# Configuration
##################################################################################

OPENERP_HOME=/var/lib/openerp
SYSTEM_HOSTNAME=openerp


##################################################################################
#  Apt-get update
##################################################################################

apt-get update

##################################################################################
# Unicode Settings
##################################################################################

source /vagrant/shell/locale-setup.bsh
cat /vagrant/shell/locale-setup.bsh >> /etc/bash.bashrc

locale-gen en_US.UTF-8
dpkg-reconfigure locales

##################################################################################
#  Setup Host
##################################################################################

echo "$SYSTEM_HOSTNAME" > /etc/hostname
# update host file
sed -i "s/\([^-]\)localhost/\1$SYSTEM_HOSTNAME/" /etc/hosts

hostname openerp

##################################################################################
#  Create groups and users
##################################################################################

groupadd developers
useradd   -d $OPENERP_HOME -G developers openerp

##################################################################################
#  Update Apt and install necessary packages for OpenERP, Postgresql, Shell and Vim
##################################################################################

apt-get install -y python-setuptools python-dev build-essential python-ldap
apt-get install -y  postgresql-9.1
apt-get install  -y postgresql-server-dev-all
#apt-get install   -y postfix - needs to be hands free - currently its not
apt-get install -y  libxml2
apt-get install -y  libxml2-dev
apt-get install -y  libxlt-dev
apt-get install -y  libxslt-dev
apt-get install -y  libldap2-dev
apt-get install -y  libldap2-dev libsasl2-dev libssl-dev
apt-get install -y  git
apt-get install -y  nginx
apt-get install -y  zsh
apt-get install -y  vim-gtk
apt-get install -y  screen
apt-get install -y libjpeg8-dev # FOR PIL
apt-get build-dep python-imaging

# for PIL / jpeg support - 32 bit only **********
ln -s /usr/lib/i386-linux-gnu/libjpeg.so /usr/lib/
ln -s /usr/lib/i386-linux-gnu/libfreetype.so /usr/lib
ln -s /usr/lib/i386-linux-gnu/libz.so /usr/lib

##################################################################################
#  PIP/VirtualEnv Setup
##################################################################################

easy_install pip
pip install virtualenv
pip install virtualenvwrapper

export WORKON_HOME=${OPENERP_HOME}/ENV
export VIRTUALENV_USE_DISTRIBUTE=1
source /usr/local/bin/virtualenvwrapper.sh


##################################################################################
#  NGINX
##################################################################################

cp /vagrant/config/openerp-nginx-config /etc/nginx/sites-available/
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/openerp-nginx-config /etc/nginx/sites-enabled/openerp-nginx-config
service nginx restart

##################################################################################
#  Prepare to install OpenERP
##################################################################################

mkdir $OPENERP_HOME/addons
cd $OPENERP_HOME


cp /vagrant/config/openerp-server.conf .
cp /vagrant/config/openerp-wsgi.py .

##################################################################################
#  Install openerp dependencies
##################################################################################

mkvirtualenv --no-site-packages openerp

workon openerp

wget http://nightly.openerp.com/7.0/nightly/src/openerp-7.0-latest.tar.gz
tar xvfz openerp-7.0-latest.tar.gz
cd openerp-7.0-20*
python setup.py install

pip install pillow # TBD

pip install gunicorn

# Creating a Wrapper around Gunicorn using our virtualenv
cat > $OPENERP_HOME/gunicorn_wrapper.sh <<EOF
#!/usr/bin/env bash
export WORKON_HOME=${OPENERP_HOME}/ENV
export VIRTUALENV_USE_DISTRIBUTE=1
source /usr/local/bin/virtualenvwrapper.sh

export PYTHON_EGG_CACHE=/tmp/egg-cache

workon openerp
exec gunicorn openerp:service.wsgi_server.application -c ${OPENERP_HOME}/openerp-wsgi.py
EOF

chown -R openerp:developers $OPENERP_HOME
chmod -R 775 $OPENERP_HOME

##################################################################################
#  Postgres config hacks and user setup
##################################################################################

cat >> /etc/postgresql/9.1/main/pg_hba.conf <<EOF
local   all             openerp                                 trust
EOF
echo "listen_addresses = '*'" >> /etc/postgresql/9.1/main/postgresql.conf

# postgres permissions for openerp user
sudo -u postgres createuser --createdb --no-createrole --no-superuser openerp

sudo -u postgres psql -c "alter user openerp with encrypted password 'abc123!!!'"

service postgresql restart

##################################################################################
# Setting up a WSGI HTTP Server
##################################################################################

cat > /etc/init/openerp.conf <<EOF
description "openerp"

start on (filesystem)
stop on runlevel [016]

respawn
console log
setuid openerp
setgid developers
# Required to create the PID file in a writable folder
chdir $OPENERP_HOME

exec $OPENERP_HOME/gunicorn_wrapper.sh
EOF


start openerp

##################################################################################
# POST Install
##################################################################################

# stash in common bash script for later use
cat >> /etc/bash.bashrc <<EOF
# Variables added by Vagrant provisoner
export OPENERP_HOME="$OPENERP_HOME"

export WORKON_HOME=\${OPENERP_HOME}/ENV
export VIRTUALENV_USE_DISTRIBUTE=1
source /usr/local/bin/virtualenvwrapper.sh
EOF

echo
cat <<-EOF
=============================================================
                   OpenERP is started!!
=============================================================

               Host:  http://localhost:8080/
               Guest: http://localhost:80/

=============================================================
> less +F /var/log/upstart/openerp.log
=============================================================
EOF
