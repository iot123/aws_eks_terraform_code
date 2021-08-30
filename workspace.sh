var=$1$2
terraform workspace list | grep $var
if [ $? -ne 0 ]
 then
   terraform workspace new $var
else
  echo " workspace is  exist"
fi
terraform workspace select $var
