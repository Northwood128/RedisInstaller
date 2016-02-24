#!/bin/bash

PROGNAME=$(basename $0)
MAKEBIN=$(which make)

function createDirs {
    #Create the necessary directories for the instalation
    if [[ ! -d /etc/redis ]] ; then
        echo "Creating config directory in /etc/redis/"
    	mkdir -v /etc/redis
    fi
    if [[ ! -d /var/redis ]] ; then
        echo "Creating data directory in /var/redis/"
    	mkdir -v /var/redis
    fi
}

function build {
    #Extract the files and build redis
    TAR=$(ls | grep redis-) 
    tar zxf $TAR
    #... I can use it here
    cd $REDIS
    $MAKEBIN
}

function copyBinaries {
    #Copy binaries to $PREFIX
    cd src
    echo "Copying redis binaries to $PREFIX"
    for bin in $(find . -mindepth 1 -perm /u=x,g=x,o=x) ; do
        cp -v $bin $PREFIX
    done
    cd ..
}

function downloadRedis {
    #Download the tar file and continues with the installation process
    echo "Downloading Redis v$VERSION"
    #This little secret. This variable is available to all the functions I call here so ...
    REDIS="redis-$VERSION"
    URL="http://download.redis.io/releases/redis-$VERSION.tar.gz"
    http_code=$(curl -o redis-$VERSION.tar.gz -w '%{http_code}\n' $URL)
    if [[ $http_code -ne "200" ]] ; then
	echo "We cannot download the version you have selected. Please check that the version you want\n"
	echo "resides on http://download.redis.io/releases/"
	exit 1
    fi
    build
    createDirs
}

function createConfig {
    #Set the port redis will listen to
    echo "We'll create a separate config and init scripts for each instance(ports) you choose"
    echo "Make sure that your server can accept connections on the ports you have listed"
    IFS=','
    pwd
    for port in $PORTS ; do
        cp utils/redis_init_script /etc/init.d/redis_$port
	sed -i "s/REDISPORT=6379/REDISPORT=$port/g" /etc/init.d/redis_$port
        sed -i  "4 a # chkconfig:   - 85 15\n\# description:  Redis is a persistent key-value database\n\# processname: redis\n" /etc/init.d/redis_$port
        cp redis.conf /etc/redis/$port.conf
	if [[ ! -d /var/redis/$port ]] ; then
	    mkdir /var/redis/$port
        fi
    done
}

while [[ $# > 0 ]] ;
do
key="$1"

case $key in
    -p|--prefix)
	export PREFIX=$2
    shift # past argument
    ;;
    -P|--port)
        export PORTS=$2
    shift # past argument
    ;;
    -d|--download)
	#Just download the tar file
        echo "Downloading Redis v$2"
	http_code=$(curl -o redis-$2.tar.gz -w '%{http_code}\n'http://download.redis.io/releases/redis-$2.tar.gz)
	if [[ $http_code -ne "200" ]] ; then
	    echo "We cannot download the version you have selected. Please check that the version you want\n"
	    echo "resides on http://download.redis.io/releases/"
	    exit 1
	fi
	exit 0
    shift # past argument
    ;;
    -V|--version)
	export VERSION=$2
    shift # past argument
    ;;
    -h|--help)
        echo "$PROGNAME: "
	echo "-V, --version:	Use this parameter to choose the Redis version to download from here http://download.redis.io/releases/"
	echo "-p, --prefix:	This is the prefix use to run the redis binaries after instalation. i.e /usr/local/bin/redis-server, /usr/local/bin is the prefix"
	echo "-P, --ports:	The port were each instance of redis is going to run. If you specify more than one port, the installation will create."
	echo " the configuration for each instance. i.e 5000,6000,7000 will create 3 instances of redis, one for each port"
	echo "-h, --help:	Will print this help"
	exit 0
    shift # past argument
    ;;
    \?)
        echo "Usage: "
	echo "$PROGNAME --version 2.8.20 -p /usr/local/bin -P 7000,8000,9000"
	echo "$PROGNAME -h 1 #Will print help"
    ;;
esac
shift # past argument or value
done

downloadRedis
copyBinaries
createConfig
