#!/bin/bash
# Initializing directories, the config file, the access controls, the DB, and
# the serials
initialize(){
	echo "Creating directories..."
	mkdir -p pkix/$name/{certs,crl,csr,newcerts,private}
	cd pkix/$name
	echo "Setting access controls to priate/..."
	sudo chmod 700 private/
	echo "Creating directories: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Configuring OpenSSL..."
	sudo cp /usr/lib/ssl/openssl.cnf ./
	echo "Setting default directory..."
	sed -i "/Where everything is kept/c\\dir 	=	`pwd`	# Where everything is kept" openssl.cnf

	echo -e "DONE\nMaking subjects unique..."
	sed -i "/#unique_subject/c\\unique_subject  = yes # Set to 'no' to allow creation of" openssl.cnf

	echo -e "DONE\nSetting default extensions"
	sed -i "/x509_extensions/c\\x509_extensions = v3_server" openssl.cnf

	echo -e "DONE\nSetting default days"
	sed -i "/default_days/c\\default_days    = 90                   # how long to certify for. 90 is recommended by Mozill" openssl.cnf

	echo -e "DONE\nSetting default hash function..."
	sed -i "/default_md/c\\default_md      = sha512               # use public key SHA3 hash algorithm, with 512-bit output. It is the strongest." openssl.cnf
	
	echo -e "DONE\nSetting default country name"
	sed -i "/countryName_default/c\\countryName_default = AL" openssl.cnf

	echo -e "DONE\nSetting default state name"
	sed -i "/stateOrProvinceName_default/c\\stateOrProvinceName_default        = Algiers" openssl.cnf

	echo -e "DONE\nSetting default organization name"
	sed -i "/0.organizationName_default/c\\0.organizationName_default  = Alboutica" openssl.cnf

	echo -e "DONE\nSetting default password length"
	sed -i "/challengePassword_min/c\\challengePassword_min = 10" openssl.cnf

	echo -e "DONE\nSetting correct keyUsage extension for the CA".
	sed -i "/# keyUsage = cRLSign, keyCertSign/c\\keyUsage             = cRLSign, keyCertSign, digitalSignature" openssl.cnf

	echo -e "DONE\nSetting default subjectAltName to email."
	sed -i "/# subjectAltName=email:copy/c\\subjectAltName=email:copy" openssl.cnf

	echo -e "DONE\nSetting default issuerAltName to issuer's DN"
	sed -i "/issuerAltName=issuer:copy/c\\issuerAltName=issuer:copy" openssl.cnf

	echo -e "DONE\nSetting up policy qualifiers for the CA"
	sed -i "/issuerAltName=issuer:copy/a\certificatePolicies = ia5org, 1.2.3.4, 1.5.6.7.8, @polsect" openssl.cnf

	echo -e "DONE\nCreating a new section: polsection"
	echo "[polsect]
policyIdentifier = 1.3.5.8
userNotice.1 = @notice

[notice]
explicitText = "This CA policy covers the following requirements: Common Name is required, other fields are optional. All certificates must comply with the CA\'s operational standards and policies."
organization = "Alboutica"
noticeNumbers = 1, 2, 3, 4" >> openssl.cnf

	echo -e "DONE\nAdding a new section: v3_server_kex"
	echo "[ v3_server_kex ]
#  These extensions are added when CA signs a request.

# This goes against PKIX guidelines but some CAs do it and some software
# requires this to avoid interpreting an end user certificate as a CA.

basicConstraints        = cA:FALSE

# PKIX recommendations harmless if included in all certificates.
authorityKeyIdentifier  = keyid,issuer
subjectKeyIdentifier    = hash
keyUsage                = keyAgreement, digitalSignature
policyQualifiers        = @policy_qualifiers
# This stuff is for subjectAltName and issuerAltname.
# Import the email address.
subjectAltName          = email:copy
# An alternative to produce certificates that aren,t
# deprecated according to PKIX.
# subjectAltName=email:move

issuerAltName           = issuer:copy
extendedKeyUsage        = serverAuth" >> openssl.cnf

	echo -e "DONE\nAdding a new section: v3_server_dh"
	echo "[ v3_server_dh ]
basicConstraints        = cA:FALSE
authorityKeyIdentifier  = keyid,issuer
subjectKeyIdentifier    = hash
keyUsage                = keyAgreement
policyQualifiers        = @policy_qualifiers
subjectAltName          = email:copy
issuerAltName           = issuer:copy
extendedKeyUsage        = serverAuth" >> openssl.cnf

	echo -e "DONE\nConfiguring OpenSSL: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Creating DB index.txt"
	touch index.txt
	echo "DB creation: DONE"

	echo -e "\n--------------------------------------------------------------------\n"
	if [ ! -f serial ] ; then
		echo "Creating serial and CRL serial"
		echo 00 > serial
		echo 00 > crlnumber # If either of them exist, then the other does as 
							# well. I can't imagine a setup with only a serial.
	fi
	echo -e "\n--------------------------------------------------------------------\n"

	echo "Evinronment creation: DONE."

	echo -e "\n--------------------------------------------------------------------\n" 
	
	echo "Proceeding to root CA generation..."	
	gen_root_cert # Calling function to generate root CA cert
	echo "Root CA generation: DONE"

	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Creating revokation list..."
	sudo openssl ca -config openssl.cnf -gencrl -out crl.pem # We need root
					# access because we don't have access to the private key.
	echo "Revokation list creation: DONE"
}

# A function to generate root self-signed certs
gen_root_cert(){
	echo "We now will generate a private Elliptic Curve Digital Signature Algorithm (ECDSA) key, in one of the best curves, in human readable format (called PEM).  This ECDSA key, with this curve, is the one recommended by Mozilla for modern security."
	key="del-cakey.pem"
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out private/$key
	echo "ECDSA key generation: DONE. It is named 'cakey.pem'"

	echo -e "\n--------------------------------------------------------------------\n"
		
	echo -e "Next, let's change the format to PKCS#8 format, which is the standard. It will prompt you for (1) sudo password --because of access contorls--, and a passphrase.\nThe passphrase is needed for encrypting the key. This way, we add a second layer of security.\nMake sure to memorize it, or use a password manager such as Proton Pass."
	sudo openssl pkcs8 -topk8 -inform PEM -outform PEM -in private/$key -out private/cakey.pem -v2 aes128
	echo "Format changing: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Deleting old, unencrypted private key so that it cannot be recovered..."
	shred -n 10 -u private/$key # shred will make sure that the file is unrecoverable
	echo "Old key deletion: DONE"
	key="cakey.pem"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Setting access controls to the key..."
	sudo chmod 400 private/$key
	echo "Setting access controls: DONE. Next: you must set the right owner to the key."

	echo -e "\n--------------------------------------------------------------------\n" 
	
	echo "Before we create the certificate, let's set the Certificate Revocation List (CRL) Distribution Point, which is the point you'll use to distribute the CRL. Other's will use it to verify that a cert signed by you is not revoked."
	echo "Enter the CRL distribution point URI. [e.g., https://crl.example-root-ca.com/crl.pem ]"
	echo "WARNING: Once it is set, you cannot change it."
	echo "NOTE: the crl is currently named 'ca.pem', located in crl/"
	read crldp
	sudo sed -i "/\[ v3_ca \]/a\crlDistributionPoints = URI:https://crl.qsecurity.com/crl.pem" openssl.cnf
	echo "Setting CRL Distribution Point: DONE"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Now, we will create a self-signed cert for our CA, in x.509 format, that lasts 10 years, with SHA2 512 hash function. This will use your privte key, so it will prompt you for the passphrase"

	sudo openssl req -config openssl.cnf -key private/$key -new -x509 -days 3650 -sha512 -extensions v3_ca -out ./cacert.pem
	sudo chmod 444 certs/cacert.pem
	
	echo "Cert creation: DONE. The cert is now accessible by anyone to read."
	
	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Creating a DER copy of the certificate."
	openssl x509 -outform der -in cacert.pem -out cacert.der
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
	echo "Before we proceed, make sure that this script is running in the right location. Everything that we will create will be a sub-directory/sub-files of this directory. Proceed? [Y/n]"
	read choice
	
	while : ; do
		if [[ $choice != "n" && $choice != "y" && $choice != "N" && $choice != "Y" ]] ; then # Invalid input
			echo "Invalid input. Try again."
			read choice
		elif [[ $choice == "n" || $choice == "N" ]] ; then # Wrong directory
			echo "Wrong directory, exiting..."
			exit 0
	
		else # right directory
			break
		fi
	done
	echo "Greate! Let's keep going"

	echo -e "\n--------------------------------------------------------------------\n"

	echo "Choose a name for your local root CA"
	read name
	echo "Greate name!"
	
	echo -e "\n--------------------------------------------------------------------\n"
	
	echo "Initializing.."
	initialize $name

	echo "Users must now deliver their CSR to your csr/. From there, you can sign them."
	echo "Scrip ends here."
	echo -e "Things to do next\n1. Add profiles to openssl.cnf for extensions (make a backup).\n2. Configure the CRL extension in the profiles."
}


# Call main() function
main
