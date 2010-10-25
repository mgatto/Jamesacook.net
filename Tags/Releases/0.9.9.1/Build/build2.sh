#! /bin/bash

# must be run as root
if [ ! "`whoami`" = "root" ]; then
    echo "Please run script as root."
    exit 1
fi

PROGNAME="$0"
SHORTOPTS="f:t:c::d:v:"
LONGOPTS="from:,to:,conf::,repository::,archive::,domain:,version:,rewrite,reverse-rewrite,compress-css::,compress-js::"
SVN=0
ZIP=0
TO="$PWD"
CONF="no"
VERSION=""
ARCHIVE=""
REPOSITORY=""
REWRITE="no"
COMPRESS="no"
CSSFILES=""
JSFILES=""

ARGS=$(getopt -s bash --options $SHORTOPTS  \
  --longoptions $LONGOPTS --name $PROGNAME -- "$@" )

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around $ARGS: they are essential!
eval set -- "$ARGS"

while true ; do
    case "$1" in
        -f|--from)
            echo "Option -f|--from, argument \`$2'" ;
            case "$2" in
                "svn")
                    SVN=1 ;
                    shift 2
                    ;;
                "zip")
                    ZIP=1 ;
                    shift 2
                    ;;
                 *)
                    echo "No other formats are supported" ;
                    exit 1
                    ;;
            esac
            ;;
        -t|--to)
            echo "Option -t|--to, argument \`$2'" ;
            TO="$2" ;
            shift 2
            ;;
        -d|--domain)
            echo "Option -d|--domain, argument \`$2'" ;
            DOMAIN="$2"
            shift 2
            ;;
        -v|--version)
            echo "Option -v|--version, argument \`$2'" ;
            VERSION="$2"
            shift 2
            ;;
        -c|--conf)
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    CONF="$2" ;
                    if [ -r "$2" ]; then
                        source $CONF
                    fi

                    shift 2
                    ;;
            esac
            ;;
        --rewrite)
            echo "Rewrite links to ADD_DOMAIN"
            REWRITE="ADD_DOMAIN"
            shift
            ;;
        --reverse-rewrite)
            echo "Rewrite links to REMOVE_DOMAIN"
            REWRITE="REMOVE_DOMAIN"
            shift
            ;;
        --compress-css)
            echo "Option --compress-css, argument \`$2'" ;
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    CSSFILES="$2" ;
                    shift 2
                    ;;
            esac
            ;;
        --compress-js)
            echo "Option --compress-js, argument \`$2'" ;
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    JSFILES="$2" ;
                    shift 2
                    ;;
            esac
            ;;
        --repository)
            echo "Option --repository, argument \`$2'" ;
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    REPOSITORY="$2" ;
                    shift 2
                    ;;
            esac
            ;;
        --archive)
            echo "Option --archive, argument \`$2'" ;
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    ARCHIVE="$2" ;
                    shift 2
                    ;;
            esac
            ;;
        --)
            shift ;
            break
            ;;
        *)
            echo "Internal error!" ;
            exit 1
            ;;
    esac
done


# usage: set_owner user group
set_owner_and_group() {
    USER=$1
    GROUP=$2

    # this is one reason this script needs to be run as root
    echo "Changing file ownership to $USER:$GROUP"
    chown "$USER:$GROUP" . -R
}

symlink() {
    echo "Symlinking"
    # symlink htdocs
    ln -sfn $VERSION htdocs
}


get_from_svn() {
    svn export \
        $1 \
        $TO/$VERSION;

    # Get the videos which are not under VC
    echo "Importing video files"
    cp ./htdocs/media/video/*.f4v ./$VERSION/media/video/
}

get_from_zip() {
    # check signature; gpg returns 0 if all is well, 1 for bad sig.
    echo "Checking signature of Jamesacook.net-$VERSION.zip"
    if [ $(gpg --verify $ARCHIVE.sig $ARCHIVE) -ne 0 ];
    then
      echo "Signature verification failed!"
      exit 1
    fi

    #unzip it; -a converts windows EOL -> UNIX; but, it thinks jpg and flv are text
    unzip "$ARCHIVE" -d ./
}

#get_from_hg() {}
#get_from_tbz2() {}
#get_from_tar.bz2() {} #alias of get_from_tbz2()

rewrite_links() {
    # rewrite links to add in the domain so the url is as such:
    # [http://dev.example.com] /$DOMAIN/index.html

    # rewrite links if necessary
    case $REWRITE in
        "ADD_DOMAIN" )
            echo "rewriting links to ADD the domain name"
            find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) | xargs sed -i \
                -e "s|href=\"/|href=\"/$DOMAIN/|g" \
                -e "s|src=\"/|src=\"/$DOMAIN/|g" \
                -e "s|url('/|url('/$DOMAIN/|g" \
                -e "s|url(/|url(/$DOMAIN/|g" \
                -e "s|uri = \"/|uri = \"/$DOMAIN/|g" \
                -e "s|src: '/|src: '/$DOMAIN/|g" \
                -e "s|url: '/|url: '/$DOMAIN/|g";
            ;;
        "REMOVE_DOMAIN" )
            # reverse the link rewriting...
            echo "rewriting links to REMOVE the domain name"
            find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) | xargs sed -i \
                -e "s|href=\"/$DOMAIN/|href=\"/|g" \
                -e "s|src=\"/$DOMAIN/|src=\"/|g" \
                -e "s|url('/$DOMAIN/|url('/|g" \
                -e "s|url(/$DOMAIN/|url(/|g" \
                -e "s|uri = \"/$DOMAIN/|uri = \"/|g" \
                -e "s|src: '/$DOMAIN/|src: '/|g" \
                -e "s|url: '/$DOMAIN/|url: '/|g";
            ;;

        * )
            ;;
    esac
}

# Remove VCS and Editor Templates and artifacts
cleanup_files() {
    #delete .svn Dreamweaver _notes dirs
    find . -name ".svn" -type d -exec rm -rf {} \;
    find . -name ".hg" -type d -exec rm -rf {} \;
    find . -name ".git" -type d -exec rm -rf {} \;
    find . -name ".bzr" -type d -exec rm -rf {} \;
    find . -name "_notes" -type d -exec rm -rf {} \;

    # Delete Templates, Library and Build
    rm -rf ./Templates
    rm -rf ./Library
    rm -rf ./Build
}

strip_comments() {
    echo "Stripping coments, including Dreamweaver Template commands"
    find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) | xargs sed -i \
        -e 's|<!--.*-->||g';
}

#depends on YUI Compressor in build dir
combine_js() {
    NAME="scripts-$VERSION.min.css"

    #combine the named files
    for jsfile in $JSFILES; do
        cat $jsfile >> $NAME
        rm -f $jsfile
    end

}

combine_css() {
    NAME="styles-$VERSION.min.css"

    #combine the named files
    for cssfile in $CSSFILES; do
        cat $cssfile >> $NAME

        # delete the lines in html with this css file and replace with $name
        find . -type f -name "*.html" | xargs sed -i \
            -e "$cssfile d"
        &&
        rm -f $cssfile
    end

    # now add in the new $NAME CSS link
    find . -type f -name "*.html" | xargs sed -i \
"
<!--[if IE]> i\
<link rel=\"stylesheet\" type=\"text/css\" href=\"/css/lib/$NAME\" media=\"screen\" \/>
"
}

minify() {
    find . -type f \( -name "*.js" -a -not name "jquery*" \) | sudo xargs -I {} \
        java -jar $TO/build/yuicompressor-2.4.2.jar --type js {} -o {} --charset utf-8  --line-break 0

    find . -type f -name "*.css" | sudo xargs -I {} \
        java -jar $TO/build/yuicompressor-2.4.2.jar --type css {} -o {} --charset utf-8  --line-break 0
}

# depends on pngcrush
optimize_img() {
    pngcrush
    jpegtran -optimize -progressive < original.jpg > optimized.jpg

}

usage()
{
  cat << EO
        Usage: $PROGNAME [options]
               $PROGNAME -o <version> -c

        Increase the .deb file's version number, noting the change in the


        Options:
EO
  cat <<EO | column -s\& -t

        -h|--help & show this output
        -V|--version & show version information
EO
}

#logging requires log4sh
#if [ -r log4sh ]; then
#  LOG4SH_CONFIGURATION='none' . ./log4sh
#else
#  echo "ERROR: could not load log4sh" >&2
#  exit 1
#fi

# change the default message level from ERROR to INFO
#logger_setLevel INFO

# say hello to the world
#logger_info "Hello, world!"

echo "Preparing to build."
echo "Current Directory: $PWD"
echo "Changing to: $TO"
cd "$TO"

if [ -z $VERSION ]; then
    read -p "Which version are we deploying?" VERSION || exit 1;
fi

# does the VERSION dir already exist?
if [ -d "$VERSION" ]; then
    echo "Version: $VERSION already exists."
    read -p "Delete it?" DELETE

    case $DELETE in
        [Yy]* )
            rm -rf "./$VERSION"
            echo "Deleted $TO/$VERSION"
            ;;
        [Nn]* )
            ;;
        * )
            echo "Please answer yes or no."
            ;;
    esac
fi

# Get the web files from a source
if [ $ZIP -eq 1 -a $ARCHIVE != "" ]; then
        get_from_zip $ARCHIVE
elif [ $SVN -eq 1 -a $REPOSITORY != ""]; then
        get_from_svn $REPOSITORY
exit 0
else
    echo "I don't know what to do next."
fi

# Shall we rewrite links and src?
if [ $REWRITE != "no" ]; then
    rewrite_links $REWRITE
fi

# Shall we minify js or css, or both? Images, too?
# This should always come after Rewriting of links, if any.
if [ $COMPRESS != "no" ]; then
    compress $COMPRESS
fi

cleanup_files
strip_comments
minify
# symlink must come before set_owner_and_group so the htdocs symlink ist't stuck as owned by root
symlink
set_owner_and_group www-data www-data

echo "Deployed!"