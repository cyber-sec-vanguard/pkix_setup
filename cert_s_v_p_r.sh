#!/bin/bash
# main function

sign(){
        echo "Enter the certificate name"
	ls csr
	read cert
	openssl ca -config openssl.cnf -notext -md sha3-256 -in csr/$cert -out certs/$cert
}

verify(){
	echo "Enter the user's certificate's name"	
	ls certs
	read cert
	echo "Enter the CA's certificate's name"
	ls certs
	read ca
	openssl verify -CAfile certs/$ca certs/$cert
}

printout(){
	echo "Enter the certificate's name"
	ls certs
	read cert
	openssl x509 -in certs/$cert -noout -text
}

revoke(){
	echo "Enter the certificate's name"
        ls certs
        read cert
	openssl ca -config openssl.cnf -revoke certs/$cert
	echo -e "Done.\nRefreching CRL"
	openssl ca -config openssl.cnf -gencrl -out crl/ca-crl.pem
	echo "Want to check the CRL? (yes/no)"
	read choice
	while : ; do
		if [[ $choice != "no" && $choice != "yes" ]] ; then
                	echo "Please, enter either 'yes', or 'no'. Keep it simple"
                        read choice
                elif [[ $choice = "yes" ]] ; then
                        openssl crl -in crl/ca-crl.pem -noout -text
			return 0
		fi
        done
}

main(){
	echo "------------------------------Welcome!------------------------------"
        echo "This script will help you establish and run your local root Certificate Authority"
        echo -e "\n--------------------------------------------------------------------\n"
	echo "Make sure to run this script in the PKIX directory. Proceed? (yes/no)"
	read choice
        while : ; do
                if [[ $choice != "no" && $choice != "yes" ]] ; then
                        echo "Please, enter either 'yes', or 'no'. Keep it simple"
                        read choice
                elif [[ $choice = "no" ]] ; then
                        exit 0
		else
			break
                fi
        done
        while : ; do
		echo -e "Greate! Now select an option\n0. Exit.\n1. Sign a certificate.\n2. Verify a certification\n3. Print out a certificate.\n4. Revoke a certificate."
		read choice
		if [[ $choice = 0 ]] ; then
        		exit 0
        	elif [[ $choice = 1 ]] ; then
			sign
		elif [[ $choice = 2 ]] ; then
			verify
		elif [[ $choice = 3 ]] ; then
			printout
		elif [[ $choice = 4 ]] ; then
			revoke
		else
			echo "Invalid input"
		fi
	done
}

main
