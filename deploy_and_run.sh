#!/bin/bash


function install_nodejs() {
  curl -fsSL https://deb.nodesource.com/setup_14.x | sudo -E bash -
  sudo apt-get install -y nodejs
  handel_errors "Failed to install nodejs"
}

function handel_errors(){
	error_message=$1
       	if [ $? -ne 0 ]
	then
       		echo "$error_message"
      		exit 1
      	fi

}

install_nodejs

echo "---------------------------------------"

function create_ip_config() {
    sudo tee /etc/netplan/01-network-manager-all.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: no
      addresses: [10.0.2.15/24]
      gateway4: 10.0.2.2
      nameservers:
          addresses: [192.168.1.1,172.20.10.1]

EOF
  sudo netplan apply
  sudo systemctl restart NetworkManager
  handel_errors "Failed to create ip config"

}

create_ip_config

echo "---------------------------------------"

function create_node_user() {
  sudo adduser node --disabled-password --gecos "Node"
  handel_errors "Failed to creat user node"
}

create_node_user

echo "---------------------------------------"


function get_ip_address() {
  ip_address=$(ip -o -4 addr show enp0s3 | awk '{print $4}' | sed 's/\/.*$//')  
}


get_ip_address

echo "---------------------------------------"

function install_postgres() {

    sudo apt-get update
    sudo apt-get install postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    sudo systemctl status postgresql
    sudo -u postgres psql -c "CREATE DATABASE demo_app_db;"
    sudo -u postgres psql -c "CREATE USER omar WITH PASSWORD 'omar';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE demo_app_db TO omar;"
    handel_errors "Failed to install postgres"

}

install_postgres

echo "---------------------------------------"

function clone_repo() {
    git clone https://github.com/omarmohsen/pern-stack-example.git
    cd pern-stack-example
    handel_errors "Failed to creat clone repo"


}

clone_repo

echo "---------------------------------------"

function run_ui_tests() {
	
  cd ui
  npm install
  npm audit fix
  npm run test &  
  handel_errors "Failed to run ui test"

  
}

run_ui_tests

echo "---------------------------------------"


function build_ui() {
 
  npm run build  
  cd ../
  echo "$PWD"
  handel_errors "Failed to build ui"

}

build_ui

echo "---------------------------------------"

function create_backend_environment() {
  cd api
  npm install
  npm audit fix
  sed -i "/if (env === "demo") {/a\    process.env.HOST = "'"$ip_address"'";\n    process.env.PGUSER = "omar";\n    process.env.PGPASSWORD = "omar";\n    process.env.PGHOST = "'"$ip_address"'";\n    process.env.PGPORT = "5432";\n    process.env.PGDATABASE = "demo_app_db";" webpack.config.js
  ENVIRONMENT=demo npm run build
  handel_errors "Failed to create backend env"

}

create_backend_environment
echo "---------------------------------------"

function package_and_start() {
  cd ../
  cp -r api/dist/* .
  cp api/swagger.css .
  npm install pg
  node api.bundle.js
  handel_errors "Failed to start app"

}

package_and_start


echo "app started and running"
