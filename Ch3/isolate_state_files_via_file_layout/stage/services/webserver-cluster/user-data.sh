#!/bin/bash
# This script accesses the variables defined in the main.tf, in the vars section of
# data.template_file.user_data. Note that you don't need var.db_address
# to access db_address defined there.
# One of the benefits of extracting scripts into their own files is that you can
# write tests on it. Environment variables can be created to fill in interpolated
# variables in the script (bash syntax for looking up env variables is same as
# terraform's syntax). Example test for this script:
#
# export db_address=12.34.56.78
# export db_port=5555
# export server_port=8888
#
# ./user-data.sh
#
# output=$(curl "http://localhost:$server_port")
#
# if [[ $output == *"Hello, World"* ]]; then
#    echo "Success! Got expected text from server."
# else
#    echo "Error. Did not get back expected text 'Hello, World'."
# fi
cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

nohup busybox httpd -f -p ${server_port} &
