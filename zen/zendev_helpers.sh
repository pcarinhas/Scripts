# Modify this device export for your device
if [[ -z $device ]]; then
   # export device=nutanix64
   # export device=nutanixLabAHV
   export device=mp6.zenoss.loc
fi

# Don't modify below this line, unless you know what to do
# ----------------------------------------------------------------------------

alias ss='serviced service'
alias ssa='serviced service attach'
alias ssaz='serviced service attach zope/0 su - zenoss'
alias ssl='serviced service list'
alias ssr='serviced service run'
alias ssrz='serviced service run zope'
alias sss='serviced service status'
alias st='serviced template'
alias std='serviced template deploy'
alias stl='serviced template list'
alias zope='serviced service attach zope/0 su zenoss -l'
alias hub='serviced service attach zenhub su zenoss -l'                         
alias hubdebug='serviced service attach zenhub su - zenoss -c "zenhub debug"'   
alias hubtail="tail -F $ZENHOME/log/zenhub.log"          
alias zenre='serviced service restart $1'                 
alias br='git branch'
alias co='git checkout'
alias dif='git diff'
alias difstat='git diff --stat'
alias ff=' find . -not -path "*/.git/*" -not -path "*/.cache/*" '
alias gst='git diff --stat'
alias log='git log'
alias pull='git pull'
alias st='git status'
alias zpls=zplist


# Attach to any container: ssax /zenopenstack
function ssax()
{
   serviced service attach "$1"/0 su - zenoss
}

# Set device to your current dev device

get_dev()
{
   if [ ! -z $1 ]; then
      local dev="$1"
   else
      local dev="$device"
   fi
   echo "$dev"
}

# Run zenmodeler against device. You can specify device or use default
zenmo ()
{
   local dev=$(get_dev $1)
   if [[ $CONTROLPLANE ]]; then 
      zenmodeler run -d $dev -v10 |& tee /tmp/zenmo.log
   else
      serviced service attach zope/0 su - zenoss -c "zenmodeler run -d $dev -v10" \
         |& tee /tmp/zenmo.log
   fi
}
# Run zencommand against device. You can specify device or use default
zenco ()
{
   local dev=$(get_dev $1)
   if [[ $CONTROLPLANE ]]; then 
      zencommand run -d $dev -v10 |& tee /tmp/zenco.log
   else
      serviced service attach zope/0 su - zenoss -c "zencommand run -d $dev -v10" \
         |& tee /tmp/zenco.log
   fi
}
# Run zenpython against device. You can specify device or use default
zenpy ()
{
   local OPTIND
   local collectors
   local extra_args
   nolog=0
   while getopts "c:nd" opt; do
      case $opt in
         c)
            collectors=$OPTARG
            echo collectors = $collectors
            ;;
         n)
            nolog=1
            ;;
         d)
            debug=1
            ;;
         \?)
            echo "Invalid option: -$OPTARG" >&2
            return 1;
            ;;
      esac
   done
   shift $((OPTIND-1))

   local dev=$(get_dev $1)

   if [[ -n "$collectors" ]]; then
      extra_args=" --collect $collectors"
      echo extra_args = $extra_args
   fi

   if [[ $CONTROLPLANE ]]; then
      zenpython run -d $dev -v10 |& tee /tmp/zenpy.log
   elif [[ $debug -eq 1 ]]; then
      echo 'serviced service attach zope/0 su - zenoss -c "zenpython run -d $dev $extra_args"'
      serviced service attach zope/0 su - zenoss -c "zenpython run -d $dev $extra_args"
   else
      serviced service attach zope/0 su - zenoss -c "zenpython run -d $dev -v10 $extra_args" \
         |& tee /tmp/zenpy.log
   fi
}

# Run zenperfsnmp against device. You can specify device or use default
zensnmp ()
{
   local dev=$(get_dev $1)
   if [[ $CONTROLPLANE ]]; then 
      zencommand run -d $dev -v10 |& tee /tmp/snmp.log
   else
      serviced service attach zope/0 su - zenoss -c "zenperfsnmp run -d $dev -v10" \
         |& tee /tmp/snmp.log
   fi
}

export PROMPT_DIRTRIM=2
export TERM=xterm

# Initialize the global variables in zp
# zp Ceph >& /dev/null

# -----------------------------------------------------------------------------
# The following commands only work from the host system.
# -----------------------------------------------------------------------------

ZENZPROOT=$( jig root)

if [[ -d "$ZENHOME" ]]; then
   zp_container_base=/mnt/src
elif [[ "$zpbase" = "/z" ]]; then
   zp_container_base=/z
else
   echo "Cant find Container base folder"
fi

# Run zendmd inside your zope container
dmd ()
{
   local dev=$(get_dev $1)
   serviced service attach zope/0 su - zenoss \
      -c "device=$dev zendmd --script=$zp_container_base/myzendmd.py"
}

# List zenpacks
zplist()
{
   serviced service attach zope/0 su - zenoss -c "zenpack --list"
}

# ZenPack Install in Link mode
zpil()
{
   local name=$1
   if [[ -z $name ]]; then
      echo "You must provide zenpack name: XXX part of ZenPacks.zenoss.XXX"
      echo "using default $zpdefault"
      name=$zpdefault
   fi
   for zp in ${name} ; do
      serviced service attach zope/0 su - zenoss \
         -c "zenpack --link --install $zp_container_base/ZenPacks.zenoss.$zp"
   done
   if [[ -z $name ]]; then
      $HOME/bin/zen re
   fi
}
complete -o filenames -F _zp zpil

# ZenPack Install in Egg mode
zpie()
{
   if [[ -z $1 ]]; then
      echo "You must provide a zenpack egg name"
   fi
   for zp in ${1} ; do
      serviced service run zope zenpack-manager install $zp
   done
}

# ZenPack Remove
zprm()
{
   local name=$1
   if [[ -z $name ]]; then
      echo "You must provide zenpack names: XXX part of ZenPacks.zenoss.XXX"
      echo "using default $zpdefault"
      name=$zpdefault
   fi
   for zp in ${name} ; do
      serviced service attach zope/0 su - zenoss \
         -c "zenpack --uninstall ZenPacks.zenoss.$zp"
   done
}
complete -o filenames -F _zp zprm

# Run Unit Tests for ZenPack
runt()
{

   local OPTIND
   local module=""
   local testname=""
   local logging=false
   while getopts :n:m:l opt; do
      case $opt in
         m)
            module=$OPTARG
            ;;
         n)
            testname=$OPTARG
            ;;
         l)
            logging=true
            ;;
         \?)
            echo "Invalid option: -$OPTARG" >&2
            return 1;
            ;;
      esac
   done

   shift $((OPTIND-1))

   local args=''
   if [[ ! -z $module ]]; then
      args+=" -m $module"
   fi
   if [[ ! -z $testname ]]; then
      args+=" -n $testname"
   fi

   if [[ $logging = true ]]; then
      echo logging is true!
   fi
   if [[ -z $1 ]]; then
      echo "You can provide zenpack names: XXX part of ZenPacks.zenoss.XXX"
      echo "Using default ZP: $zpdefault"
      name=$zpdefault
   else
      echo looking at ZP: $1
      echo seeing opts as $@
      name=$1
   fi

   if [[ "$logging" = true ]]; then
       serviced service attach zope/0 su - zenoss \
          -c "runtests -vv $args ZenPacks.zenoss.$name" |& tee /tmp/runt.log
   else
       serviced service attach zope/0 su - zenoss \
          -c "runtests -vv $args ZenPacks.zenoss.$name"
   fi
}
complete -o filenames -F _zp runt

# ZenPack Remove using serviced's command: For Eggy systems
zpremove()
{
   if [[ -z $1 ]]; then
      echo "You must provide a zenpack name: XXX part of ZenPacks.zenoss.XXX"
   fi
   for zp in ${1} ; do
      serviced service run zope zenpack uninstall ZenPacks.zenoss.$zp
   done
}

# Install Zenpack via zenbatchload. You must have batchfile on the distributed file location.
zenbatch()
{
   echo "Make sure your zenbatch file is in $zp_container_base"
   for zp in ${1} ; do
      serviced service attach zope/0 su - zenoss -c "zenbatchload --nomodel $zp_container_base/$zp"
   done
}

zentail ()
{
   local file=$1

   if [[ ${file: -4} == ".txt" ]];  then
      tail -F /home/zenoss/src/europa/zenhome/log/$file
   else
      tail -F /home/zenoss/src/europa/zenhome/log/$file.log
   fi
}

muster()
{
   echo "make muster in  $zp_container_base"
   local name=$1
   if [[ -z $name ]]; then
      echo "You must provide zenpack name: XXX part of ZenPacks.zenoss.XXX"
      echo "using default $zpdefault"
      name=$zpdefault
   fi
   serviced service attach zope/0 su - zenoss -c "cd $zp_container_base/ZenPacks.zenoss.$name; make muster"
}
complete -o filenames -F _zp muster


