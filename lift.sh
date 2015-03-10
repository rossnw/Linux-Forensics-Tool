#!/bin/bash
##The goal of this script of to automate the gathering and exportation of data, as well as provide the ability to run the tools individually
##Libraries should be statically linked to the executables called and included with script

#GLOBAL VARIABLES
script="${0}"
vers="0.0.1a"
cli=false
file=false
filename="/dev/null"
netcat=false
host="nope"
port="0"
pid="0"

function main()
{
	##Check for root permissions.
	if [[ ${UID} -ne 0 ]]
	then
	        echo "${script} must be run as root" >&2
	        exit 1
	fi

	if [[ ${#} -eq 0 ]]
	then
		print_usage
		exit 1
	fi

	parse_arguments "${@}"

	print_globals

	if ${cli}
	then
		scrape
	fi

	if ${file}
	then
		scrape >> "${filename}"
	fi		

	if ${netcat}
	then
		scrape | nc -q 1 ${host} ${port}
	fi

	if ${pid}
	then
		#	make a first-in-first-out file and use it to hold the gcore output behind it
		mkfifo tmp.dmp
		#	once the user hits enter and allows the netcat session to execute, the memdump 
		#	is sent through netcat via the fifo file tied to it's active session
		read -p "ready to send memdump of PID ${pid}. Press enter when nc listener is ready " -n1 -s
		cat tmp.dmp | nc -q l ${host} ${port}
		gcore ${pid} > tmp.dmp
		#	the fifo file is deleted
		read -p "memdump sent, press enter to finish " -n1 -s
		rm -rf tmp.dmp
	fi
}

function parse_arguments()
{
	while getopts "hvco:nm" opt
	do
		case ${opt} in
			##help
			h)
				print_usage
				exit 1
			;;
			##Print version info
			v)
				echo "Version ${vers}"
				exit 1
			;;
			##output to command line
			c)
				kill_on_multiple_outputs
				cli=true
			;;
			##Write to file
			o)
				kill_on_multiple_outputs
				file=true
				filename=${OPTARG}
			;;
			##use netcat
			n)
				kill_on_multiple_outputs
				netcat=true
				IFS=':' read -ra PARTS <<< "${OPTARG}"
				host=${PARTS[0]}
				port=${PARTS[1]}
			;;
			##send PID memdump through netcat
			m)
				kill_on_multiple_outputs
				netcat=true
				IFS=':' read -ra PARTS <<< "${OPTARG}"
				pid=${PARTS[0]}
				host=${PARTS[1]}
				port=${PARTS[2]}
			;;
			\?)
				print_usage >&2
#				echo "Invalid option: -${OPTARG}" >&2
				exit 1
			;;
		esac
	done
}

function kill_on_multiple_outputs()
{
	if ((${netcat}) || (${cli}) || (${file}))
	then
		echo >&2
		echo "You have selected multiple output options." >&2
		print_usage >&2
		exit 1
	fi
}

function print_globals()
{
	cat << EOF
script    ${script}
vers      ${vers}
cli       ${cli}
file      ${file}
filename  ${filename}
netcat    ${netcat}
port      ${port}
host      ${host}
pid	      ${pid}
EOF

}

function scrape()
{
	##get start date and time
	echo ""
	echo "////////////////////"
	echo "start date and time"
	date
	echo ""
	##OS Information
	echo "////////////////"
	echo "Host and OS Information:"
	hostname
	echo "-------------------------------"
	uname -a
	cat /proc/version 
	echo ""
	cat /etc/*-release
	echo ""
	##users who have logged on
	echo "//////////////////////////////"
	echo "user(s) on system"
	cat /etc/passwd | cut -d ":" -f 1,2,3,4 2>/dev/null
	echo ""
	##interface informationl
	echo "//////////////////////////////"
	echo "network interface information"
	ifconfig
	echo ""
	## logon history
	echo "//////////////////////////////"
	echo "Logon history"
	last
	echo ""
	## cron jobs
	echo "//////////////////////////////"
	echo "root cron jobs"
	crontab -u root -l
	echo ""
	## Network State
	# netstat -an
	##Running Processes
	echo "//////////////////////////////"
	echo "Running Processes"
	ps aux
	echo ""
	##Open ports and files
	echo "//////////////////////////////////////////////////"
	echo "open processes and associated network connections"
	lsof -n -P -i
	echo ""
	##Routing and ARP Tables
	echo "////////////////////////"
	echo "Routing and ARP tables"
	netstat -rn
	echo ""
	route -Cn
	echo ""
	arp -an
	echo ""
	##process load informations
	echo "//////////////////////////////"
	echo "current load info (TOP)"
	top -n 1
	echo ""
	##currently logged on users
	echo "//////////////////////////////"
	echo "Currently logged in users"
	w
	echo ""
	
	#####
	##logs-tar and send, need to seperate
	####
	##user group information
	echo "//////////////////////////////"
	echo "etc/passwd"
	cat /etc/passwd
	echo ""
	
	##GET .bash_history files
	
	##Loaded Kernel Modules
	echo "//////////////////////////////"
	echo "loaded kernel modules"
	lsmod
	echo ""
	##End date and time
	echo "//////////////////////////////"
	echo "end date and time"
	date
	echo ""
}

# function mem_dump()
# {
# #	make a first-in-first-out file and use it to hold the gcore output behind it
# 	mkfifo tmp.dmp

# #	once the user hits enter and allows the netcat session to execute, the memdump 
# #	is sent through netcat via the fifo file tied to it's active session
# 	read -p "ready to send memdump of PID $1. Press enter when nc listener is ready " -n1 -s
# 	cat tmp.dmp | nc -q l $2 $3
# 	gcore $1 > tmp.dmp
# #	the fifo file is deleted
# 	read -p "memdump sent, press enter to finish " -n1 -s
# 	rm -rf tmp.dmp

# }

function print_usage()
{
#	read -d '' USAGE <<- EOF
	cat << EOF

Usage: ${script} [ -h | -v | -c | -o <file> | -n <host:port> | -m <pid> <host:port>]

Arguments
  -h              help
  -v              version
  -c              output to standard out
  -o <file>       output to file
  -n <host:port>  output to netcat
  -m <pid:host:port>  memdump through ncat session

EOF
}


main "${@}"
