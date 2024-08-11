#!/bin/bash
# Initializing directories, the config file, the access controls, the DB, and the serials
initialize(){
	echo "Creating directories"
	mkdir -p pkix/$name/{certs,crl,csr,newcerts,private}
	echo "done"
	echo -e "\n--------------------------------------------------------------------\n"	
	echo "Configuring OpenSSL"	
	cd pkix/$name
	echo "Setting access controls to priate/"
	sudo cp /usr/lib/ssl/openssl.cnf ./
	sed -i "/Where everything is kept/c\\dir 	=	`pwd`	# Where everything is kept" openssl.cnf
	sudo chmod 700 private
	echo "Creating DB index.txt"
	touch index.txt
	echo "Creating serial and CRL serial"
	echo 00 > serial
	echo 00 > crlnumber
	echo "Done. The evinronment is ready"
        echo -e "\n--------------------------------------------------------------------\n" 
	echo "Creating revokation list..."	
	# Generating root self-signed certificate
	gen_root_cert	
	openssl ca -config openssl.cnf -gencrl -out crl/ca-crl.pem
}

# A function to generate root self-signed certs
gen_root_cert(){
	echo "Generate a private key, in human readable format (thus PEM), and encrypt it using AES with a 256 key. This will promt you to enter a passphrase. You need to remember it, or use a Password Generator such as Proton Pass"
	openssl genrsa -aes256 -out private/ca-key.pem 4096
	chmod 400 private/ca-key.pem
	echo -e "\n--------------------------------------------------------------------\n" 
	echo "Now, we will create a self-signed cert for our CA, in x509 format (the standardized), that lasts 10 years, with SHA3 256 hash function. This will use your privte key, so it will prompt you for the passphrase"
	openssl req -config openssl.cnf -key private/ca-key.pem -new -x509 -days 3650 -sha3-256 -out certs/ca.pem
	chmod 444 certs/ca.pem
	echo "Done. The cert is now accessible by anyone to read. This way, they can verify your public key, and use it to verify signatures"
	echo -e "\n--------------------------------------------------------------------\n"
	echo "One last step. We will convert this certificate from the human-readable form, to a computer-readable form (from PEM to DER)"
	openssl x509 -outform der -in certs/ca.pem -out certs/ca.der

	echo "Done! Your cert is now ready to be used!"
	echo -e "\n--------------------------------------------------------------------\n"

}

# The main function
main(){
	echo "------------------------------Welcome!------------------------------"
	echo "This script will help you establish and run your local root Certificate Authority"
	echo -e "\n--------------------------------------------------------------------\n"
	echo "Installing the single requirement: OpenSSL"
	#sudo apt update && sudo apt install openssl
        echo -e "\n--------------------------------------------------------------------\n"
	echo "Before we proceed, make sure that this script is running in a the location. Everything that we will create will be a sub-directory/sub-files of this directory. Proceed? (yes/no)"
	read choice
	while : ; do
		if [[ $choice != "no" && $choice != "yes" ]] ; then
			echo "Please, enter either 'yes', or 'no'. Keep it simple"
			read choice
		elif [ $choice = "no" ] ; then
			exit 0
		else
			break
		fi
	done
	echo "Greate! Let's keep going"
        echo -e "\n--------------------------------------------------------------------\n"
	echo "Choose a name for your local root CA"
	read name
	echo -e "Greate name!"
	echo -e "\n--------------------------------------------------------------------\n"
	echo "Initializing.."
	# Initializing
	initialize $name

	echo "Users must now deliver their CSR to your csr/. From there, you can sign them."
	echo "Scrip ends here."
}


# Call main() function
main
