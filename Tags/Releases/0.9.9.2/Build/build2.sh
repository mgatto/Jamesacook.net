#! /bin/bash -x

# must be run as root
if [ ! "`whoami`" = "root" ]; then
    echo "Please run script as root."
    exit 1
fi

PROGNAME="$0"
SHORTOPTS="f:t:c::d:v:h"
LONGOPTS="from:,to:,conf::,repository::,archive::,domain:,version:,rewrite,reverse-rewrite,combine-css::,combine-js::help"
SVN=0
ZIP=0
TO="$PWD"
CONF="no"
VERSION=""
## although I want to use 0.9.9 and such, we must be careful to manually increment
## this so scripts-0.9.9.min.js is NOT shared between builds IF it changed, else it will be cached which we do NOT want
ARCHIVE=""
REPOSITORY=""
REWRITE="no"
COMBINE="no"
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
        --combine-css)
            echo "Option --combine-css, argument \`$2'" ;
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
        --combine-js)
            echo "Option --combine-js, argument \`$2'" ;
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
    # --non-interactive  --native-eol LF
    BASE=$1
    TO=$2
    VERSION=$3
    svn checkout "file://$BASE/Tags/Releases/$VERSION" $TO/$VERSION;

    # Get the videos which are not under VC
    echo "Importing video files"
    if [ -d ./htdocs/media/video/ ]; then
        cp ./htdocs/media/video/*.f4v ./$VERSION/media/video/
    else
        echo "Videos not found; please copy them manually"
    fi
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
    # Delete Templates, Library and Build
    rm -rf ./Templates
    rm -rf ./Library
    rm -rf ./Build

    #delete .svn Dreamweaver _notes dirs
    find . -name ".svn" -type d -exec rm -rf {} \;
    find . -name ".hg" -type d -exec rm -rf {} \;
    find . -name ".git" -type d -exec rm -rf {} \;
    find . -name ".bzr" -type d -exec rm -rf {} \;
    find . -name "_notes" -type d -exec rm -rf {} \;
}

#make sure everything is UTF-8
encode() {
    # this might not be a good idea:

#    ONLY convert file that really are in old charset to new charset
#    - if you convert a file that was already in the new charset format
#    or that you converted manually before
#    or inserted text components in new charset inbetween old text components
#
#    --- then you may get something worse ... neither UTF-8 and nor ISO-8859-1 ...
    #hence make sure your OLD file IS in OLD charset before running the tool !!


    find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) |  sudo xargs -I {} \
        iconv -c -t UTF-8 -o {} {}
        # recode understands HTML entities!
        # recode -v ..h4..utf-8 {}
        # -c omits invalid characters from output
}

strip_comments() {
    echo "Stripping coments, including Dreamweaver Template commands"
    find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) | xargs sed -i \
        -e 's|<!--.*-->||g';
}

# minify JS
# filenames are provided as a list as a CLI argument or from conf file
#combine_js() {
#    NAME="scripts-$VERSION.min.css"

    #combine the named files
#    for jsfile in $JSFILES; do
#        cat $jsfile >> $NAME
#        rm -f $jsfile
#    end
#}

#combine_css() {
#    NAME="styles-$VERSION.min.css"

    #combine the named files
#    for cssfile in $CSSFILES; do
#        cat $cssfile >> $NAME

        # delete the lines in html with this css file and replace with $name
#        find . -type f -name "*.html" | xargs sed -i \
#            -e "$cssfile d"
#        &&
#        rm -f $cssfile
#    end

    # now add in the new $NAME CSS link
#    find . -type f -name "*.html" | xargs sed -i \
#        "
#        <!--[if IE]> i\
#        <link rel=\"stylesheet\" type=\"text/css\" href=\"/css/lib/$NAME\" media=\"screen\" \/>
#        "

#        "
#        <link rel=\"stylesheet\" type=\"text/css\" href=\"/css/lib/$NAME\" media=\"screen\" \/> d\
#        "
#}

# --charset UTF-8
# Remove extra spaces and comments from HTML
minify_html() {
    echo "Stripping coments, including Dreamweaver Template commands"
    find . -type f -name "*.html" | sudo xargs -I {} \
        java -jar $TO/htmlcompressor-0.9.3.jar --type html -o {} {}
        # --remove-intertag-spaces  --remove-quotes (mgatto: "yuck!")
}
minify_css() {
    echo "Minifying CSS files"
    find . -type f -name "*.css" | sudo xargs -I {} \
        java -jar $TO/yuicompressor-2.4.2.jar --type css {} -o {} --charset utf-8  --line-break 0
}
minify_js() {
    echo "Minifying Javascript files"
    find . -type f \( -name "*.js" -a -not name "jquery*" \) | sudo xargs -I {} \
        java -jar $TO/yuicompressor-2.4.2.jar --type js {} -o {} --charset utf-8  --line-break 0
}

# depends on pngcrush
optimize_img() {
    find . -type f -name "*.png" | sudo xargs -I {} \
        optipng -o6


    find . -type f -name "*.jpg" | sudo xargs -I {} \
        jpegtran -optimize -progressive -copy none < original.jpg > optimized.jpg
        # try not to strip copyright data from the image -copy = all

}

#error() {}
#version() {}

usage()
{
  cat << EO
        Usage: $PROGNAME [options]
               $PROGNAME -o <version> -c

        Deploy a static HTML website, and optionally optimize it.


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
if [ $ZIP -eq 1 ]; then
    if [ $ARCHIVE != "" ]; then
        get_from_zip $ARCHIVE
    else
        echo "No archive for unzip was specified"
    fi
elif [ $SVN -eq 1 ]; then
    if [ $REPOSITORY != "" ]; then
        get_from_svn $REPOSITORY $TO $VERSION
    else
        echo "No repository for SVN was specified"
        exit 1
    fi
else
    echo "Could not find a source!"
    exit 1
fi

# Shall we rewrite links and src?
if [ $REWRITE != "no" ]; then
    rewrite_links $REWRITE
fi

# Shall we minify js or css, or both? Images, too?
# This should always come after Rewriting of links, if any.
if [ $COMBINE != "no" ]; then
    combine $COMBINE
fi

cleanup_files
# strip_comments
minify_js
minify_css
minify_html

# symlink must come before set_owner_and_group so the htdocs symlink ist't stuck as owned by root
symlink
set_owner_and_group www-data www-data

echo "Deployed!"