#! /bin/dash
USAGE="Usage: nginxstatuscodes $0 [-l logfile] [-h hostname [-u username]] [-s delay] [-o outputfile] [-m] [-b] [-r] [-t] [-j] [-c] [-e]"

#Parse the optional parameters. Technically everything is optional.
#I could have made the optional flags -mbrtjce but this was more straightforward
#loop through and match with a case statement
while :
do
    case $1 in
        -l) shift; l="$1";;
        -h) shift; h="$1";;
        -u) shift; u="$1";;
        -s) shift; s="$1";;
    	-o) shift; o="$1";;
        -m) m='1';;
        -b) b='1';;
        -r) r='1';;
        -t) t='1';;
        -j) j='1';;
        -c) c='1';;
	    -e) e='1';;
        --) shift; break;;
        -*) echo "FATAL ERROR: invalid argument"; exit 1;;
        *) break;;
    esac
    shift
done

buildHumanReadableLine () {

    LINE=$1
    METHOD=$2
    RESOURCE=$3
    BYTES=$4
    NOTIME=$5

    LINE='print '\"'\"'\"' $9 '\"'\"'\"' '\"' '\"

    if ! [ "0" = "$METHOD" ]; then
        LINE=${LINE}' $6 '\"'\"'\"' '\"' '\"
    fi

    if ! [ "$RESOURCE" = "0" ]; then
        LINE=${LINE}' '\"'\"'\"' $7 '\"'\"'\"' '\"' '\"
    fi

    if ! [ "$BYTES" = "0" ]; then
        LINE=${LINE}' '\"'\"'\"' $10 '\"'\"'\"' '\"' '\"
    fi

    if [ "$NOTIME" = "0" ]; then
        LINE=${LINE}' '\"'\"'\"' $4 '\"','\"' $5 '\"'\"'\"' '\"' '\"
    fi    

    echo "$LINE"
}

buildJsonLine () {

    LINE=$1
    METHOD=$2
    RESOURCE=$3
    BYTES=$4
    NOTIME=$5

    LINE='print '\"'{'\"' '\"'\"'\"' "code" '\"'\"'\"' ":" '\"'\"'\"' $9 '\"'\"'\"' '\"','\"

    if ! [ "0" = "$METHOD" ]; then
        LINE=${LINE}' '\"'\"'\"' "method" '\"'\"'\"' ":" "'\"' $6 '\"'\"'\"' '\"','\"
    fi

    if ! [ "$RESOURCE" = "0" ]; then
        LINE=${LINE}' '\"'\"'\"' "resource" '\"'\"'\"' ":" '\"'\"'\"' $7 '\"'\"'\"' '\"','\"
    fi

    if ! [ "$BYTES" = "0" ]; then
        LINE=${LINE}'  '\"'\"'\"' "bytes"  '\"'\"'\"' ":" '\"'\"'\"' $10 '\"'\"'\"' '\"','\"
    fi

    if [ "$NOTIME" = "0" ]; then
        LINE=${LINE}' '\"'\"'\"' "time" '\"'\"'\"' ":" '\"'\"'\"' $4 '\"','\"' $5 '\"'\"'\"
    fi    

     LINE=${LINE}' "}"'
     echo $LINE
   
}

humanReadableOutput () {

    OUTPUTLINE=${1:?'FATAL ERROR: Output line is not defined'}
    COLORIZE=${2:-0}
    OUTPUT_FILE=${3:-""}

    if [ "$COLORIZE" = "1" ]; then
        CODE=`echo "$OUTPUTLINE" | awk '{print substr($0,2,1);exit}'`
	if [ "$CODE" = "2" ]; then
            tput setaf 2
        elif [ "$CODE" = "3" ]; then
            tput setaf 3
        else
            tput setaf 1
        fi
    fi

    if ! [ "$OUTPUT_FILE" = "" ]; then
	    echo "$OUTPUTLINE" >> "$OUTPUT_FILE"
    else
	    echo "$OUTPUTLINE"
    fi

    if [ "$COLORIZE" = "1" ]; then
        tput setaf 7
    fi
}

writeDataLine () {
    
    OUTPUTLINE=${1:?'FATAL ERROR: Output line is not defined'}
    ITERATION=${2:-0}
    COLORIZE=${3:-0}
    OUTPUT_FILE=${4:-""}
    JSON=${5-0}

    ITERATION=`expr "$ITERATION" + 1`

    if ! [ "$JSON" = "1" ]; then
        humanReadableOutput "$OUTPUTLINE" "$COLORIZE" "$OUTPUT_FILE"
    else
        if [ "$ITERATION" = "1" ]; then
            if ! [ "$OUTPUT_FILE" = "" ]; then
                echo "$OUTPUTLINE" >> "$OUTPUT_FILE"
            else
                echo "$OUTPUTLINE"
            fi
        else
            if ! [ "$OUTPUT_FILE" = "" ]; then
                echo ','"$OUTPUTLINE"
            else
                echo ','"$OUTPUTLINE" >> "$OUTPUT_FILE"
            fi
        fi
    fi
}

outputDifference () {

    NEWLENGTH=${1:-0}
    LENGTH=${2:-0}
    LOGFILE=${3:-?'FATAL ERROR: Logfile is not defined'}
    LINE=${4:-?'FATAL ERROR: Output line is not defined'}
    OUTPUT_FILE=${5-""}
    JSON=${6-0}
    COLORIZE=${7-0}


    NEWLINES=`expr "$NEWLENGTH" - "$LENGTH"`

    if ! [ -z "$NEWLINES" ]; then
        OUTPUT=`tail -"$NEWLINES" "$LOGFILE" | awk -F' ' "{ $LINE }"`
        if [ "$JSON" = "1" ]; then
            if ! [ "$OUTPUT_FILE" = "" ]; then
                echo '[' > "$OUTPUT_FILE"
            else
                echo '['
            fi
        fi
        if [ -n "$OUTPUT" ]; then
            ITERATION=0
            echo "$OUTPUT" | while : 
    	        read OUTPUTLINE
         	do
                	writeDataLine "$OUTPUTLINE" "$ITERATION" "$COLORIZE" "$OUTPUT_FILE" "$JSON"
	        done
        fi
        if [ "$JSON" = "1" ]; then
            if ! [ $OUTPUT_FILE = "" ]; then
                echo ']' >> "$OUTPUT_FILE"
            else
                echo ']'
            fi
        fi
    fi


}

parseLogfile () {

    LOGPATH=${1:?'FATAL ERROR: Logpath is not specified'}
    HOST=${2:-""}
    USER=${3:-""}
    GAP=${4:?'FATAL ERROR: Gap is not specified'}
    LINE=${5:?'FATAL ERROR: Output line is not specified'}
    COLORIZE=${6:-0}
    JSON=${7:-0}
    EXIST=${8:-0}
    #Set the initial file length. We always want it to read immediately
    LENGTH=0

    while :
    do
        #get the access log
        if [ "$HOST" = "" ]; then
            LOGFILE="$LOGPATH"
        else
            #if a remote path is specified, we can pull the file down locally
            if ! [ "$USER" = "" ]; then
                TARGET="${USER}@${HOST}:${LOGPATH}"
            else
                TARGET="${HOST}:${LOGPATH}"
            fi

            #this can be improved several ways. One way is to check the 
            #difference on the target server and only pull down the difference, 
            #reducing the size of the download. Also we can use rsync instead of scp
            SCPCOMMAND="scp ${TARGET} ./access.log"
            ${SCPCOMMAND}
            LOGFILE="./access.log"
        fi

        #ensure to always trigger on the first check
        if [ "$LENGTH" = "0" ]; then
            LENGTH=`wc -l $LOGFILE | awk '{ print $1 }'`
            LENGTH=`expr "$LENGTH" - "1"`
        fi
    
        #Compare the difference and if there is a difference, print it out
        #in the specified format
        if [ -e "$LOGFILE" ]; then
            NEWLENGTH=`wc -l $LOGFILE | awk '{ print $1 }'`
            outputDifference "$NEWLENGTH" "$LENGTH" "$LOGFILE" "$LINE" "$OUTPUT_FILE" "$JSON" "$COLORIZE"
            LENGTH=$NEWLENGTH
        else
            echo "The nginx access log specified could not be found or is not a valid file"
            exit 1;
        fi
        
        if [ "$EXIT" = "1" ]; then
            exit 0       
        fi

        sleep "$GAP"
          
    done

}

main () {

    LOGPATH=${1:-'/var/log/nginx/access.log'}
    HOST=${2:-}
    USER=${3:-}
    GAP=${4}
    FLAGS=${5}   
    OUTPUT_FILE=${6:-""}    
    #TODO Sanitize INPUT for logpath, user, and host

    #set the flags
    METHOD=`echo "$FLAGS" | awk -F'|' '{ print $1 }'`
    BYTES=`echo "$FLAGS" | awk -F'|' '{ print $2 }'`
    RESOURCE=`echo "$FLAGS" | awk -F'|' '{ print $3 }'`
    NOTIME=`echo "$FLAGS" | awk -F'|' '{ print $4 }'`
    JSON=`echo "$FLAGS" | awk -F'|' '{ print $5 }'`
    COLORIZE=`echo "$FLAGS" | awk -F'|' '{ print $6 }'`
    EXIT=`echo "$FLAGS" | awk -F'|' '{ print $7 }'`

    #Build the output string
    if [ "$JSON" = 0 ]; then
        LINE=`buildHumanReadableLine "$LINE" "$METHOD" "$RESOURCE" "$BYTES" "$NOTIME"`
    else
        LINE=`buildJsonLine "$LINE" "$METHOD" "$RESOURCE" "$BYTES" "$NOTIME")`
    fi

    #parse the log file - this is infinite
    parseLogfile "$LOGPATH" "$HOST" "$USER" "$GAP" "$LINE" "$COLORIZE" "$JSON" "$EXIT" "$OUTPUTFILE"

    #exit
    exit 0
}

#set the flags variable because some shells will not allow too many arguments
FLAGS="${m-0}"'|'"${b-0}"'|'"${r-0}"'|'"${t-0}"'|'"${j-0}"'|'"${c-0}"'|'"${e-0}"

#MAIN
main "$l" "$h" "$u" "${s-1}" "$FLAGS" "$o"
