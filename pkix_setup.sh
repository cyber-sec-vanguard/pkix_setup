#!/bin/bash
# Initializing directories, the config file, the access controls, the DB, and
# the serials
initialize(){
	# Firstly, we need to create five directories to confront to X.509
	echo "Creating directories..."
	mkdir -p pkix/"$1"/{certs,crl,csr,newcerts,private} || exit 1
	cd "pkix/$1" || exit 1	# In case cd fails, exit the program
	echo "Setting access controls to priate/..."
	sudo chmod 700 private/ || exit 1
	echo "Creating directories: DONE"

	echo "
--------------------------------------------------------------------------------
	"

	echo "Configuring OpenSSL..."

	# Copying OpenSSL's configuration file
	sudo dd if=/etc/ssl/openssl.cnf of=./openssl.cnf
	
	printf "Setting default directory..."
	sed -i "/Where everything is kept/c\\dir = $(pwd) # Where everything is kept" \
	openssl.cnf || exit 1

	printf "DONE.

Making subjects unique..."
	sed -i "/#unique_subject/c\\unique_subject = yes # Set to 'no' to allow creation of" \
	openssl.cnf || exit 1

	printf "DONE.

Setting default extensions..."
	sed -i "/x509_extensions/c\\x509_extensions = v3_server" openssl.cnf || \
	exit 1

	printf "DONE.

Setting default days..."
	sed -i "/default_days/c\\default_days = 90 # how long to certify for. 90 is recommended by Mozill" \
	openssl.cnf || exit 1

	printf "DONE.

Setting default hash function..."
	sed -i "/default_md/c\\default_md = sha512 # use public key SHA2-512." \
	openssl.cnf || exit 1
	
	printf "DONE.

Setting default country name.
What's your country's two character code? :: "
	read country
	sed -i "/countryName_default/c\\countryName_default = $country" \
	openssl.cnf || exit 1

	printf "DONE.

Setting default state name.
What's your state's name? :: "
	read state
	sed -i "/stateOrProvinceName_default/c\\stateOrProvinceName_default = $state" \
	openssl.cnf || exit 1

	printf "DONE.

Setting default organization name.
What's your organization's name? :: "
	read org
	sed -i "/0.organizationName_default/c\\0.organizationName_default = $org" \
	openssl.cnf || exit 1

	printf "DONE.
Setting default password length... "
	sed -i "/challengePassword_min/c\\challengePassword_min = 10" openssl.cnf \
	|| exit 1

	printf "DONE.

Setting correct keyUsage extension for the CA...
This extention will set the key usage to only be used to sign certificates and
certificate revocation lists\n"
	sed -i "/# keyUsage = cRLSign, keyCertSign/c\\keyUsage = cRLSign, keyCertSign, digitalSignature" \
	openssl.cnf || exit 1

	printf "DONE.
	
Setting default subjectAltName to email...
This is to facilitate identification and communication.\n"
	sed -i "/# subjectAltName=email:copy/c\\subjectAltName=email:copy" \
	openssl.cnf || exit 1

	printf "DONE.

Setting default issuerAltName to issuer's distinguished name... "
	sed -i "/issuerAltName=issuer:copy/c\\issuerAltName=issuer:copy" \
	openssl.cnf || exit 1

	printf "DONE.

Setting up policy qualifiers for the CA.
These qualifiers are chosen to fit this need and usage... "
	sed -i "/issuerAltName=issuer:copy/a\certificatePolicies = ia5org, 1.2.3.4, 1.5.6.7.8, @polsect" \
	openssl.cnf || exit 1

	printf "DONE.

Creating a new section: [polsect] for Policy Section...
This is used for the policy qualifier.\n"

	printf "
[polsect]
	policyIdentifier = 1.3.5.8
	userNotice.1 = @notice

	[notice]
	explicitText = 'This CA policy covers the following requirements: Common Name is required, other fields are optional. All certificates must comply with the CA\'s operational standards and policies.'
	organization = 'Alboutica'
	noticeNumbers = 1, 2, 3, 4
	" >> openssl.cnf || exit 1

	printf "DONE.
Adding a new section: [ v3_server_kex ] for the server key exchange, this is 
for the elliptic curve diffie-helmann (ECDH) key establishment.\n"
	
	echo "[ v3_server_kex ] # profile
	# These extensions are added when CA signs a request.
	# This goes against PKIX guidelines but some CAs do it and some software
	# requires this to avoid interpreting an end user certificate as a CA.

	basicConstraints        = cA:FALSE # the subject is not a certificate 
									   # authority

	# PKIX recommendations harmless if included in all certificates.
	authorityKeyIdentifier  = keyid,issuer # I think this is the hash of the key
	subjectKeyIdentifier    = hash
	keyUsage                = keyAgreement, digitalSignature # used for key 
															 # establishment
	# policyQualifiers        = @policy_qualifiers
	# Import the email address.
	subjectAltName          = email:copy
	issuerAltName           = issuer:copy
	#extendedKeyUsage        = serverAuth # An other usage of the key is to 
										  # authenticate the server to the 
										  # client. I have commented it because 
										  # diffie-helmann is not used to 
										  # authenticate but to establish keys.
	" >> openssl.cnf || exit 1

	echo "DONE.

Adding a new section: [ v3_server_sig ] for server signature, i.e., elliptic 
curve digital signature algorithm (ECDSA)."

	echo "[ v3_server_sig ] # profile
	basicConstraints		= cA:FALSE
	authorityKeyIdentifier	= keyid,issuer
	subjectKeyIdentifier	= hash
	keyUsage				= digitalSignature, keyEncipherment
	#policyQualifiers		= @policy_qualifiers
	subjectAltName			= email:copy
	issuerAltName			= issuer:copy
	extendedKeyUsage		= serverAuth" >> openssl.cnf || exit 1

	echo "DONE
Configuring OpenSSL: DONE."

	echo "
--------------------------------------------------------------------------------
	"

	printf "Creating DB index.txt..."
	touch index.txt
	echo "DONE."

	echo "
--------------------------------------------------------------------------------
	"
	if [ ! -f serial ] ; then
		printf "Creating serial and CRL serial..."
		echo 00 > serial
		echo 00 > crlnumber # If either of them exist, then the other does as 
							# well. I can't imagine a setup with only a serial.
		echo "DONE."
	fi
	echo "
--------------------------------------------------------------------------------
	"

	echo "Evinronment creation: DONE."

	echo "
--------------------------------------------------------------------------------
	" 
	
	printf "Proceeding to root CA generation..."	
	gen_root_cert # Calling function to generate root CA cert
	echo "DONE"

	echo "
--------------------------------------------------------------------------------"
	
	printf "Creating revokation list..."
	sudo openssl ca -config openssl.cnf -gencrl -out crl.pem || exit 1
					# We need root access to the private key.
	echo "DONE"
}

# A function to generate root self-signed certs
gen_root_cert(){
	echo "
We now will generate a private Elliptic Curve Digital Signature Algorithm 
(ECDSA) key, in one of the best curves, in human readable format (called PEM). 
This ECDSA key, with this curve, is the one recommended by Mozilla for modern 
server security."

	key="del-cakey.pem"
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out \
	private/$key || exit 1
	echo "ECDSA key generation: DONE. It is named 'cakey.pem'"

	echo "
--------------------------------------------------------------------------------"
		
	echo "
Next, let's change the format to PKCS#8 format, which is the standard. It will 
prompt you for (1) sudo password --because of access contorls--, and a 
passphrase. The passphrase is needed for encrypting the key. This way, we add a 
second layer of security.
Make sure to memorize it, or use a password manager such as Proton Pass."
	
	sudo openssl pkcs8 -topk8 -inform PEM -outform PEM -in private/$key -out \
	private/cakey.pem -v2 aes128 || exit 1
	echo "Format changing: DONE"

	echo "
--------------------------------------------------------------------------------"

	printf "
Deleting old, unencrypted private key so that it cannot be recovered..."
	# shred will make sure that the file is unrecoverable
	shred -n 10 -u private/$key || exit 1
	echo "DONE"
	key="cakey.pem"

	echo "
--------------------------------------------------------------------------------
	"
	printf "Setting access controls to the key..."
	sudo chmod 400 private/$key || exit 1
	echo "DONE. Next, you must set the right owner to the key."

	echo "
--------------------------------------------------------------------------------"

	printf "
Before we create the certificate, let's set the Certificate Revocation List 
(CRL) Distribution Point, which is the point you'll use to distribute the CRL. 
Other's will use it to verify that a cert signed by you is not revoked.
WARNING: Once it is set, you cannot change it.
NOTE: the crl is currently named 'crl.pem', located in the current directory (./).
Enter the CRL distribution point URI, 
[ e.g., https://crl.example-root-ca.com/crl.pem ] :: "
	read crldp || exit 1
	sed -i "/\[ v3_ca \]/a\\crlDistributionPoints = URI:$crldp" openssl.cnf || \
	exit 1
	echo "DONE"

	echo "
--------------------------------------------------------------------------------"

	echo "
Now, we will create a self-signed cert for our CA, in X.509 format, that lasts 
10 years, with SHA2-512. This will use your private key, so it will prompt you 
for the passphrase."

	sudo openssl req -config openssl.cnf -key private/$key -new -x509 -days \
	3650 -sha512 -extensions v3_ca -out ./cacert.pem || exit 1
	sudo chmod 444 cacert.pem || exit 1
	
	echo "Cert creation: DONE. The cert is now accessible by anyone to read."
	
	echo "
--------------------------------------------------------------------------------
	"	
	printf "Creating a DER copy of the certificate..."
	openssl x509 -outform der -in cacert.pem -out cacert.der || exit 1
	echo "DONE"

	echo "
--------------------------------------------------------------------------------
	"
	echo "Done! Your cert is now ready to be used!"
}

# The main function
main(){
	echo "------------------------------Welcome!------------------------------"
	echo "This script will help establish local root Certificate Authority"
	echo "
--------------------------------------------------------------------------------
	"
	echo "Installing the single requirement: OpenSSL"
	if command -v dnf &> /dev/null; then
		sudo dnf install openssl
	elif command -v apt &> /dev/null; then
		sudo apt update && sudo apt install openssl
	elif command -v yum &> /dev/null; then
		sudo yum install openssl
	elif command -v pacman &> /dev/null; then
		sudo pacman -S openssl
	elif command -v zypper &> /dev/null; then
		sudo zypper install openssl
	else
		echo "No compatible package manager found. Please install OpenSSL
manually."
		exit 1
	fi
	echo "
--------------------------------------------------------------------------------
	"
	printf "
Before we proceed, make sure that this script is running in the right location. 
Everything that we will create will be a sub-directory/sub-files of this 
directory. Proceed? [Y/n] :: "
	
	while : ; do
		read choice
		if [[ $choice == "n" || $choice == "N" ]] ; then # Wrong directory
			echo "Wrong directory, exiting..."
			exit 0

		elif [[ $choice != "y" && $choice != "Y" ]] ; then # Invalid input
			printf "Invalid input. Try again :: "

		else # right directory
			break
		fi
	done
	echo "Greate! Let's keep going"

	echo "
--------------------------------------------------------------------------------
	"

	printf "Choose a name for your local root CA :: "
	read name
	echo "Greate name!"
	
	echo "
--------------------------------------------------------------------------------
	"
	
	echo "Initializing.."
	initialize "$name"

	echo "
	Users must now deliver their CSR to your csr/. From there, you can sign 
	them."

	echo "Scrip ends here."
	echo "Things to do next
	1. Add profiles to openssl.cnf for extensions (make a backup).
	2. Configure the CRL extension in the profiles."
}

# Call main() function
main