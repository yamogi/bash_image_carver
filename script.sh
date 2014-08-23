#!/bin/bash
#############################
# Author:  Haydon Murdoch
# Date:    26/03/2014
# Title:   script.sh
# Purpose: To extract multiple image files
#          from a raw image automatically.
#############################

function check_arguments { # checking the number of arguments
	echo "" # newline for readbility

	if [ $# -eq 0 ] # if zero arguments...
	then
		echo -e "\tZero arguments supplied"
		how_to_use # then [EXIT]
	elif [ $# -eq 1 ] # correct number of arguments
	then
		echo -e "\tChecking existence of $1..."
		check_file_exists "$@" # call file-checking function
	else # if more than one arguments...
		echo -e "\tMore than one argument supplied"
		how_to_use # then [EXIT]
	fi
}

function how_to_use { # called if script activated with incorrect number of arguments
	echo -e "\tUsage: ./[script] [file to extract]"
	echo "" # newline for readability
	exit 0
}

function check_file_exists { # code to check if file actually exists
	if [ -e $1 ] # i.e. if file to read exists
	then
		echo -e "\tFile exists."
		echo ""
		read -p "    Please press [enter] key to continue:"
		echo ""
		number_of_images "$@" # call image counter function
	else # file does not exist
		echo -e "\tSorry, file does not exist"
		echo ""
		exit 0
	fi
}

function number_of_images { # code to discover number of images in raw data file
	starts=$(xxd $1 | grep -E 'ff[[:space:]]?d8' | wc -l) # count number of times "FFD8" or "FF D8" appears
	ends=$(xxd $1 | grep -E 'ff[[:space:]]?d9' | wc -l) # count number of times "FFD9" or "FF D9" appears

	if [ $starts -eq $ends ] # if the numbers match...
	then
		#display_xxd_starts "$@"     # for demo purposes - disabled
		#display_xxd_ends "$@"       # for demo purposes - disabled
		echo "    $starts images found in file"
		echo "    Now initiating file carving"
		extract_images $starts "$@" # call image extraction function
	else # if the numbers don't match...
		echo -e "\tNumber of images mismatch."
		echo -e "\tProgram will now close."
		exit 0
	fi
}

# function display_xxd_starts {
# -------------------------------------------------------------------
# ----- code to display ffd8s found in file (for demo purposes) -----
# -------------------------------------------------------------------
#	echo ""
#	echo -e "\tBeginning of images:"
#	echo ""
#	xxd -u $1 | grep --color -E 'FF[[:space:]]?D8'
#}
#
# function display_xxd_ends {
# -------------------------------------------------------------------
# ----- code to display ffd9s found in file (for demo purposes) -----
# -------------------------------------------------------------------
#	echo ""
#	echo -e "\tEnd of images:"
#	echo ""
#	xxd -u $1 | grep --color -E 'FF[[:space:]]?D9'
#}

function extract_images { # code to extract images one by one
	N=1 # initialising loop counter

	echo ""

	while [ $N -le $1 ]; do # i.e., until counter "N" reaches the number of images discovered in the file
		# /--------------------------------\
		# ---------- start values ----------
		# \--------------------------------/
		# find line with "FFD8" or "FF D8" on it
		# grep -m and tail is used creatively here
		start_find=$(xxd -u $2 | grep -m $N -E 'FF[[:space:]]?D8' | tail -n1)
		# split this line around the colon ':'
		#  - field 1 = offset of that line (in hex),
		#              converted to upper case
		#  - field 2 = the rest of the line,
		#              with the spaces removed
		start_f1=$(echo $start_find | cut -d':' -f 1 | tr '[:lower:]' '[:upper:]')
		start_f2=$(echo $start_find | cut -d':' -f 2 | tr -d ' ')
		# converting the line offset into bytes
		initial_offset_start=$(echo "ibase=16;$start_f1" | bc)
		# splitting the rest of the line with
		# "FFD8" as the field delimiter
		start_offset_1=$(echo $start_f2 | awk -F"FFD8" '{print $1}')
		# finding out the length of
		# the line up to that point
		awk_length=${#start_offset_1}
		# dividing this number by two
		# to convert it to bytes
		start_offset_2=$(echo "$awk_length / 2" | bc)
		# finding out the offset for
		# the start of the image
		start_of_image=$(echo "$initial_offset_start + $start_offset_2" | bc)
		echo -e "\tStart of image in bytes: $start_of_image"

# -------------------- end of start values --------------------

		# /------------------------------\
		# ---------- end values ----------
		# \------------------------------/
		# find line with "FFD9" or "FF D9" on it
		# grep -m and tail is used creatively here
		end_find=$(xxd -u $2 | grep -m $N -E 'FF[[:space:]]?D9' | tail -n1)
		# split this line around the colon ':'
		#  - field 1 = offset of that line (in hex),
		#              converted to upper case
		#  - field 2 = the rest of the line,
		#              with the spaces removed
		end_f1=$(echo $end_find | cut -d':' -f 1 | tr '[:lower:]' '[:upper:]')
		end_f2=$(echo $end_find | cut -d':' -f 2 | tr -d ' ')
		# converting the line offset into bytes
		initial_offset_end=$(echo "ibase=16;$end_f1" | bc)
		# splitting the rest of the line with
		# "FFD8" as the field delimiter
		end_offset_1=$(echo $end_f2 | awk -F"FFD9" '{print $1}')
		# finding out the length of
		# the line up to that point
		awk_length=${#end_offset_1}
		# dividing this number by two
		# to convert it to bytes
		end_offset_2=$(echo "$awk_length / 2" | bc)
		# finding out the offset for
		# the start of the image
		#  /----------------------\
		# |--------- NOTE ---------|
		#  \----------------------/
		# in this case, the "+ 2" is needed to reach the end of "FFD9",
		# otherwise the byte count only reaches where FFD9 -begins-
		end_of_image=$(echo "$initial_offset_end + $end_offset_2 + 2" | bc)
		echo -e "\tEnd of image in bytes:   $end_of_image"

# -------------------- end of end values --------------------


		# ---------- calculating and displaying filesize  ----------
		filesize=$(echo "$end_of_image - $start_of_image" | bc)
		echo -e "\tFilesize in bytes:       $filesize"

# -------------------- end of filesize calculation --------------------


		# ---------- carving the image ----------
		echo -e "\tCarving file..."

		if [ -e $2\($N\).jpg ] # if filename already exists
		then
			echo -e "\tFilename $2($N) already exists!"
			echo -e "\tPlease choose a different filename, while omitting the .jpg extension"
			echo -e "\t\tOtherwise, please press [enter] to overwrite the old file"

			read newname

			if [ "$newname" = "" ] # if the user simply pressed [enter]
			then
				dd if=./$2 bs=1 skip=$start_of_image count=$filesize \
				of=./$2\($N\).jpg > /dev/null 2>&1 # overwrite old file
				echo ""
				echo -e "\tImage file number $N successfully carved and saved as \"$2($N).jpg\""
				echo ""
			else # if a name was entered...
				if [ ! -e $newname.jpg ]
				then
					dd if=./$2 bs=1 skip=$start_of_image count=$filesize \
					of=./$newname.jpg > /dev/null 2>&1 # create new file
					echo ""
					echo -e "\tImage file number $N successfully carved and saved as \"$newname.jpg\""
					echo ""
				fi
			fi
		else # if filename DOESN'T already exist
			dd if=./$2 bs=1 skip=$start_of_image count=$filesize \
			of=./$2\($N\).jpg > /dev/null 2>&1
			echo ""
			echo -e "\tImage file number $N successfully carved and saved as \"$2($N).jpg\"" # carve file normally
			echo ""
		fi

# -------------------- end of image carving --------------------


		# ----- incrementing the loop counter -----
		((N++)) # script will now be looking for next file in image
		# -----------------------------------------

		echo "" # newline for readability
	done
}

######## initiating the program ########
check_arguments "$@"
