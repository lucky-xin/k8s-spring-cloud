#!/bin/bash
images_names=('datainsights-auth' 'datainsights-register' 'datainsights-tx-manager' 'datainsights-upms-biz')

for jar_name in ${images_names[@]};
do
#   cp ../"$jar_name"/target/"$jar_name".jar czm@192.168.10.82:/home/czm/datainsights-app/"$jar_name"
   cp ../"$jar_name"/target/"$jar_name".jar jar
done