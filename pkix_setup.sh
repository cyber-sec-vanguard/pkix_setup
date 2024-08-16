#!/bin/bash



# Initializing directories, the config file, the access controls, the DB, and the serials
initialize(){
	echo "Creating directories..."
	mkdir -p pkix/$name/{certs,crl,csr,newcerts,private}	
	cd pkix/$name
	echo "Setting access controls to priate/..."
	sudo chmod 700 private
	echo "Creating directories: DONE"
	
	echo -e "\n--------------------------------------------------------------------\n"	
	
	echo "Configuring OpenSSL..."
	sudo cp /usr/lib/ssl/openssl.cnf ./
	echo "Setting default directory..."
	sed -i "/Where everything is kept/c\\dir 	=	`pwd`	# Where everything is kept" openssl.cnf
	echo -e "DONE\nSetting default days..."
	sed -i "/default_days/c\\default_days    = 90                   # how long to certify for. 90 is recommended by Mozill" openssl.cnf
	echo -e "DONE\nSetting default hash function..."
	sed -i "/default_md/c\\default_md      = sha3-512               # use public key SHA3 hash algorithm, with 512-bit output. It is the strongest." openssl.cnf
	echo -e "DONE\nConfiguring OpenSSL: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Creating DB index.txt"
	touch index.txt
	echo "DB creation: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Creating serial and CRL serial"
	echo 00 > serial
	echo 00 > crlnumber
	
	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Evinronment creation: DONE."
        
	echo -e "\n--------------------------------------------------------------------\n" 
	
	echo "Proceeding to root CA generation..."	
	gen_root_cert # Calling function to generate root CA cert
	echo "Root CA generation: DONE"

	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Creating revokation list..."
	sudo openssl ca -config openssl.cnf -gencrl -out crl/ca-crl.pem # We need root access because we don't have access to the private key.
	echo "Revokation list creation: DONE"
}

# A function to generate root self-signed certs
gen_root_cert(){
	echo "We now will generate a private Elliptic Curve Digital Signature Algorithm (ECDSA) key, in one of the best curves, in human readable format (called PEM).  This ECDSA key, with this curve, is the one recommended by Mozilla for modern security."
	key="del-ca-key.pem"
	#openssl genrsa -aes256 -out private/ca-key.pem 4096 # Gen 4096 bit key
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp521r1 -out private/$key
		# This elliptic curve is said to be backdoored by the NSA.
	echo "ECDSA key generation: DONE. It is named 'ca-key.pem'"
	
	echo -e "\n--------------------------------------------------------------------\n"
		
	echo "Next, let's change the format to PKCS#8 format, which is the standard. It will prompt it for (1) sudo password, and a passphrase, because we will encrypt the key so that no one can use it; double security! Make sure to memorize it, or use a password manager such as Proton Pass."
	sudo openssl pkcs8 -topk8 -inform PEM -outform PEM -in private/$key -out private/ca-key.pem -v2 aes256
	echo "Format changing: DONE"

	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Deleting old, unencrypted private key so that it cannot be recovered..."
	shred -n 10 -u private/$key # shred will make sure that the file is unrecoverable
	echo "Old key deletion: DONE"
	key="ca-key.pem"
	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Setting access controls to the key..."
	sudo chmod 400 private/ca-key.pem
	echo "Setting access controls: DONE. Next: you must set the right owner to the key."

	echo -e "\n--------------------------------------------------------------------\n" 
	
	echo "Before we create the certificate, let's set the Certificate Revocation List (CRL) Distribution Point, which is the point you'll use to distribute the CRL. Other's will use it to verify that a cert signed by you is not revoked."
	echo "Enter the CRL distribution point URI. [i.g., https://crl.example-root-ca.com/ca-crl.pem ]"
	echo "WARNING: Once it is set, you cannot change it."
	echo "NOTE: the crl is currently named 'ca-crl.pem', located in crl/"
	read crldp
	sed -i "/[ v3_ca ]/a\\crlDistributionPoints = URI:$crldp"
	
	echo "Setting CRL Distribution Point: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Now, we will create a self-signed cert for our CA, in x509 format (the standardized), that lasts 10 years, with SHA3 256 hash function. This will use your privte key, so it will prompt you for the passphrase"
	
	sudo openssl req -config openssl.cnf -key private/$key -new -x509 -days 3650 -sha3-256 -out certs/ca.pem
	sudo chmod 444 certs/ca.pem
	
	echo "Cert creation: DONE. The cert is now accessible by anyone to read. This way, they can verify your public key, and use it to verify signatures"
	
	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Convertting the certificate from the human-readable form PEM, to a computer-readable form DER..."
	openssl x509 -outform der -in certs/ca.pem -out certs/ca.der
	echo "Cert form conversion: DONE"

        echo -e "\n--------------------------------------------------------------------\n"                     

	echo "Done! Your cert is now ready to be used!"
}

# The main function
main(){
	echo "------------------------------Welcome!------------------------------"
	echo "This script will help you establish and run your local root Certificate Authority"
	echo -e "\n--------------------------------------------------------------------\n"
	echo "Installing the single requirement: OpenSSL"
	sudo apt update && sudo apt install openssl
        echo -e "\n--------------------------------------------------------------------\n"
	echo "Before we proceed, make sure that this script is running in the right location. Everything that we will create will be a sub-directory/sub-files of this directory. Proceed? (yes/no)"
	read choice
	
	while : ; do
		if [[ $choice != "no" && $choice != "yes" ]] ; then # Invalid input
			echo "Please, enter either 'yes', or 'no'. Keep it simple"
			read choice
	
		elif [ $choice = "no" ] ; then # Wrong directory
			echo "Wrong directory, exiting..."
			exit 0
	
		else
			break # right directory
		fi
	done
	echo "Greate! Let's keep going"
        
	echo -e "\n--------------------------------------------------------------------\n"

	echo "Choose a name for your local root CA"
	read name
	echo -e "Greate name!"
	
	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Initializing.."
	initialize $name

	echo "Users must now deliver their CSR to your csr/. From there, you can sign them."
	echo "Scrip ends here."
	echo -e "Things to do next\n1. Add profiles to openssl.cnf for extensions (make a backup).\n2. Configure the CRL extension in the profiles."
}


# Call main() function
main
