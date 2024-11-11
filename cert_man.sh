#!/bin/bash
# main function

create(){
	printf "Select a key to create.
	[1] RSA key (discouraged).
	[2] Elliptic Curve parameters (for ECDSA/ECDH).
	[0] Exit
	
	Your input :: "
	while : ; do
		read choice
		if [[ $choice == 0 ]] ; then
			return 0
		
		elif [[ $choice == 1 ]] ; then
			openssl genpkey -algorithm RSA -out private/kpriv_rsa.pem -pkeyopt \
			rsa_keygen_bits:3072 -outform PEM || exit 1
			echo "The key is called kpriv_rsa.pem"
			return 0
		
		elif [[ $choice == 2 ]] ; then
			openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
			-out private/kpriv_ec.pem -outform PEM || exit 1
			echo "The key is called kpriv_ec.pem"
			return 0
		
		else
			printf "Invalid input. Try again :: "
			read choice
		fi
	done
}

csr(){
	echo "Select the private key."
	keys=(private/*) # List the items and store them in the variable	
	echo "[-1] Exit"
	for i in "${!keys[@]}"; do
		echo "[$i] ${keys[i]}"
	done
	printf "Your input :: "
	while : ; do
		read choice
		if [[ $choice = "-1" ]] ; then
			echo "Exiting .."
			return 0
		elif [[ $choice > $i ]] ; then # Bash allows you to sum integers with 
									  # strings :)
			printf "Invalid choice. Try again :: "
		else
			openssl req -config openssl.cnf -outform PEM -out \
			csr/csr-"new" -new -key "${keys[choice]}" \
			-sha512 || exit 2
			break
		fi
	done
	echo "WARNING: You should rush to change its name"
}

sign(){
	echo "Select the certificate."
	ls cert
	csrs=(csr/*) # List the items and store them in the variable	
	echo "[-1] Exit"
	for i in "${!csrs[@]}"; do
		echo "[$i] ${csrs[i]}"
	done
	printf "Your input :: "
	while : ; do
		read choice
		if [[ $choice = "-1" ]] ; then
			echo "Exiting .."
			return 0
		elif [[ $choice > $i ]] ; then # Bash allows you to sum integers with 
									  # strings :)
			printf "Invalid choice. Try again :: "
		else
			echo "
Add extensions.. The initiating script stamps profiles with a mark to 
distinguish them. If you have created other profiles, this script will be 
incapable of detecting them unless they're stamped as others are. To stamp them,
simply add '# profile' after the directive"
			grep "# profile" openssl.cnf || exit 7
			printf "Your input :: "
			read ext
			sudo openssl ca -config openssl.cnf -notext -extensions "$ext" -in \
			"${csrs[choice]}" -out certs/newcert.cert || exit 3
			break	
		fi
	done
}

verify(){
	echo "Select the certificate."
	certs=(certs/*)
	echo "[-1] Exit"
	for i in "${!certs[@]}"; do
		echo "[$i] ${certs[i]}"
	done
	while : ; do
		printf "Your input :: "
		read choice
		if [[ $choice = "-1" ]] ; then
			echo "Exiting .."
			return 0
		elif [[ $choice > $i ]] ; then # Bash allows you to sum integers with 
									  # strings :)
			echo "Invalid choice. Try again"
		else
			openssl verify -crl_check -CRLfile ./crl.pem -CAfile cacert.pem \
			"${certs[choice]}" || exit 4
			break	
		fi
	done
}

printout(){
	echo "Select the certificate."
	certs=(private/*)
	echo "[-1] Exit"
	for i in "${!certs[@]}"; do
		echo "[$i] ${certs[i]}"
	done
	while : ; do
		printf "Your input :: "
		read choice
		if [[ $choice = "-1" ]] ; then
			echo "Exiting .."
			return 0
		elif [[ $choice > $i ]] ; then # Bash allows you to sum integers with 
									  # strings :)
			echo "Invalid choice. Try again"
		else
			openssl x509 -in certs/"$cert" -noout -text	|| exit 5		
			break	
		fi
	done
	
	
}

revoke(){
	echo "Select the certificate."
	certs=(private/*)
	echo "[-1] Exit"
	for i in "${!certs[@]}"; do
		echo "[$i] ${certs[i]}"
	done
	while : ; do
		printf "Your input :: "
		read choice
		if [[ $choice = "-1" ]] ; then
			echo "Exiting .."
			return 0
		elif [[ $choice > $i ]] ; then # Bash allows you to sum integers with 
									  # strings :)
			echo "Invalid choice. Try again"
		else
			sudo openssl ca -config openssl.cnf -revoke certs/"$cert" || exit 6
			printf "Done.
Refreching CRL.."
			sudo openssl ca -config openssl.cnf -gencrl -out crl.pem			
			break	
		fi
	done
	
}

main(){
	echo "
------------------------------------Welcome!------------------------------------
"
	echo "
This script will help you establish and run your local root Certificate 
Authority"

	echo "
--------------------------------------------------------------------------------
	"

	printf "Make sure to run this script in the PKIX directory. 
Proceed? [Y/n] :: "
	while : ; do
		read choice
		if [[ $choice == "n" || $choice == "N" ]] ; then 
			echo "Wrong directory, exiting .."
			exit 0

		elif [[ $choice != "y" && $choice != "Y" ]] ; then
			printf "Invalid input. Try again [Y/n] ::"

		else # right dir, continuing
			break
		fi
	done
	echo "Greate! Now select an option"
	while : ; do
		printf "
	[0] Exit.
	[1] Generate a private key.
	[2] Generate a CSR.
	[3] Sign a cert.
	[4] Verify a cert.
	[5] Revoke a cert.
	[6] Print out a cert.
	
	Your input :: "

		read choice
		if [[ $choice = 0 ]] ; then
			exit 0
		elif [[ $choice = 1 ]] ; then
			create
		elif [[ $choice = 2 ]] ; then
			csr
		elif [[ $choice = 3 ]] ; then
			sign
		elif [[ $choice = 4 ]] ; then
			verify
		elif [[ $choice = 5 ]] ; then
			revoke
		elif [[ $choice = 6 ]] ; then
			printout
		else
			echo "Invalid input."
		fi
	done
}
main