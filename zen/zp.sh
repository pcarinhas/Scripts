export zpdefault=Ceph

if [[ -z "$zpbases" ]]; then

   echo "No zpbases set"

   if [[ $SRCROOT ]]; then
      zpbases=()
      echo seen SRCROOT = $SRCROOT

      if [ -d "$SRCROOT/zenpacks" ]; then
         zpbases+=("$SRCROOT/zenpacks")
         echo seen zpbases
      fi

      if [ -d "$SRCROOT/github.com/zenoss" ]; then
         zpbases+=("$SRCROOT/github.com/zenoss")
         echo seen zpbases
      fi

   else

      echo "No SRCROOT found"
      if [ -d /z ]; then
         zpbases+=("/z")
      fi

   fi
   export zpbases

fi

zp() 
{ 
   # --------------------------------------------------------------------------
   # Setup up variables..
   # --------------------------------------------------------------------------
   if [[ -z "$zpdefault" ]]; then
      export zpdefault=PythonCollector
   fi

   local OPTIND
   gotobase=0
   while getopts ":b" opt; do
      case $opt in
         b)
            gotobase=1
            shift $((OPTIND-1))
            ;;
         \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
      esac
   done

   # --------------------------------------------------------------------------
   # Find and go to right folders
   # --------------------------------------------------------------------------
   local zpname
   if [ -z "$1" ]; then

      echo "Using default zp $zpdefault";
      # zp $zpdefault;
      zpname=$zpdefault

   elif [[ "$1" == "-" ]]; then
      pushd +1 &> /dev/null
      return
   else
      zpname=$1

   fi
      
   for base in ${zpbases[@]}; do

      if [ -d "$base"/"$zpname" ]; then
         pushd "$base"/"$zpname" &> /dev/null;
         export zpbase=$base
         return;
      fi;

      local second="ZenPacks.zenoss.$zpname";
      local basedir="$base"/"$second"
      if [[ $gotobase -eq 1 ]] && [[ -d "$basedir" ]]; then
         pushd "$basedir" &> /dev/null
         export zpbase=$base
         return;
      fi;


      third=${second//./\/};
      final="$base"/"$second"/"$third"/;

      if [ -d "$final" ]; then
         pushd "$final" &> /dev/null
         export zpbase=$base
         return;
      fi;

   done

}


# Function for command completion of zp: adjust for non-commercial use.
function _zp()
{
   local cmd="${1##*/}"
   local word=${COMP_WORDS[COMP_CWORD]}
   # Pointer to current completion word.
   # By convention, it's named "cur" but this isn't strictly necessary.

   words=""
   for base in ${zpbases[@]}; do

      for i in $base/ZenPacks.zenoss.${word}*; do
         if [[ -d $i ]]; then
            # words+="${i##*.*.}"
            # words+="${i#*.*.}"
            # words+="${i##$base/ZenPacks.zenoss.}"
            words+="${i##$base/ZenPacks.zenoss.}"
            words+=" "
         fi
      done
      for i in $base/${word}*; do
         if [[ ! ${i##*/} =~ [.] ]] && [[ -d $i ]]; then
            words+="${i##*/}"
            words+=" "
         fi
      done

   done

   COMPREPLY=()   # Array variable storing the possible completions.
   COMPREPLY=( $( compgen -W "$words" -- $cur ) )
}

# complete is require to activate command completion
complete -o filenames -F _zp zp

