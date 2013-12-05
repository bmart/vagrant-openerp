Openerp Install w/ Vagrant
=============================

## Requirements

* virtualbox
* vagrant
* git


## Steps to build environment

1. Install Virtualbox, vagrant, and git   

2. clone this repo:
   git clone https://github.com/bmart/vagrant-openerp.git

3. cd into vagrant-openerp

4. run this:
   vagrant up

5. With any luck, you should be able to go to localhost:8080 and see a fresh working install of openerp on a fresh database




## Thanks
* thanks to this guy https://github.com/dreur for helping with the gunicorn/nginx/upstart basics

## TODO
* show example with AWS provider
* postfix - I don't have the install automated. Probably should be using something like puppet or saltstack for this stuff anyhow








