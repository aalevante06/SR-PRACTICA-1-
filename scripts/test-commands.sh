#!/usr/bin/env bash
# Laboratorio autorizado 2174

curl -k https://10.21.74.130
nc -vz -w 3 10.21.74.146 3306
curl -v "http://10.21.74.130/?id=1%20UNION%20SELECT%201,2,3"
curl -v -o /tmp/prueba2174.exe http://10.21.74.130/prueba2174.exe
