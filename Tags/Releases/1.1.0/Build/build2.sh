#! /bin/bash -x

#In a compound test, even quoting the string variable might not suffice. [ -n
#"$string" -o "$a" = "$b" ] may cause an error with some versions of Bash if
#$string is empty. The safe way is to append an extra character to possibly empty
#variables, [ "x$string" != x -o "x$a" = "x$b" ] (the "x's" cancel out).

# must be run as root
if [ ! "`whoami`" = "root" ]; then
    echo "Please run script as root."
    exit 1
fi

PROGNAME="$0"
SHORTOPTS="f::t::c::d::v::h"
LONGOPTS="from::,to::,conf::,repository::,archive::,domain::,version::,rewrite,reverse-rewrite,combine-css::,combine-js::,help"
SVN=
ZIP=
TO="$PWD"
DOMAIN=
CONF=
VERSION=
## although I want to use 0.9.9 and such, we must be careful to manually increment
## this so scripts-0.9.9.min.js is NOT shared between builds IF it changed, else it will be cached which we do NOT want
ARCHIVE=
REPOSITORY=
REWRITE=
COMBINE=
CSSFILES=
JSFILES=
TMP=temp

usage() {
  cat <<EO
        Usage: $PROGNAME [options]

        Deploy a static HTML website, and optionally optimize it.

        Options:
EO
  cat <<EO | column -s\& -t

        -h|--help & show this output
        -V|--version & show version information
EO
exit 0
}


ARGS=$(getopt -s bash --options $SHORTOPTS  \
  --longoptions $LONGOPTS --name $PROGNAME -- "$@" )

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around $ARGS: they are essential!
eval set -- "$ARGS"

while true ; do
    case "$1" in
        -f|--from)
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
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
                    shift 2
                    ;;
            esac
            ;;
        -t|--to)
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    echo "Option -t|--to, argument \`$2'" ;
                    TO="$2" ;
                    shift 2
                    ;;
            esac
            ;;
        -d|--domain)
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    echo "Option -d|--domain, argument \`$2'" ;
                    DOMAIN="$2"
                    shift 2
                    ;;
            esac
            ;;
        -v|--version)
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    echo "Option -v|--version, argument \`$2'" ;
                    VERSION="$2" ;
                    shift 2
                    ;;
            esac
            ;;
        -c|--conf)
            case "$2" in
                "")
                    shift 2
                    ;;
                *)
                    CONF="$2"
                    if [ -r "$2" ]; then
                        source $CONF
                    fi

                    shift 2
                    ;;
            esac
            ;;
        --rewrite)
            echo "Rewrite links to ADD_DOMAIN"
            REWRITE="ADD_DOMAIN" ;
            shift
            ;;
        --reverse-rewrite)
            echo "Rewrite links to REMOVE_DOMAIN"
            REWRITE="REMOVE_DOMAIN" ;
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
        -h|--help)
            usage
            shift
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

##
symlink() {
    echo "Symlinking"
    # symlink htdocs
    ln -sfn $VERSION htdocs
}

##
get_from_svn() {
    echo "Getting files from Subversion Repository"
    # --non-interactive  --native-eol LF
    BASE=$1
    TO=$2
    VERSION=$3
    svn checkout "file://$BASE/Tags/Releases/$VERSION" $TO/$VERSION;

    # Get the videos which are not under VC
    echo "Importing video files"
    if [ -d $TO/htdocs/assets/videos/ ]; then
        cp $TO/htdocs/assets/videos/*.f4v $TO/$VERSION/assets/videos/
    else
        echo "Videos not found; please copy them manually"
    fi
}

##
get_from_zip() {
    echo "Deploying from a Zip archive"

    # check signature; gpg returns 0 if all is well, 1 for bad sig.
    echo "Checking signature of Jamesacook.net-$VERSION.zip"
    if [ $(gpg --verify $ARCHIVE.sig $ARCHIVE) -ne 0 ];
    then
      echo "Signature verification failed!"
      exit 1
    fi

    #unzip it;
    # -a converts windows EOL -> UNIX; but, it thinks jpg and flv are text
    unzip "$ARCHIVE" -d ./

    # Get the videos which are no longer stored in the ZIP file since it takes 238MB / 248MB
    if [ -d $TO/htdocs/assets/videos/ ]; then
        cp $TO/htdocs/assets/videos/*.f4v $TO/$VERSION/assets/videos/
    else
        echo "Videos not found; please copy them manually"
    fi
}

#get_from_hg() {}
#get_from_tbz2() {}
#get_from_tar.bz2() {} #alias of get_from_tbz2()

##
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
    echo "Deleting VCS, DW Notes, Templates, Build and Library files"

    # Delete Templates, Library and Build
    rm -rf "$VERSION/Templates"
    rm -rf "$VERSION/Library"
    rm -rf "$VERSION/Build"
    rm -rf "$VERSION/assets/css/lib"
    rm -rf "$VERSION/assets/js/lib"

    #delete .svn Dreamweaver _notes dirs
    find . -name ".svn" -type d -exec rm -rf {} \;
    find . -name ".hg" -type d -exec rm -rf {} \;
    find . -name ".git" -type d -exec rm -rf {} \;
    find . -name ".bzr" -type d -exec rm -rf {} \;
    find . -name "_notes" -type d -exec rm -rf {} \;
}

##
check_spelling() {
    find . -type f -name "*.html" | sudo xargs -I {} \
        apsell {}
}

## Make sure everything is UTF-8
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
    find ./$VERSION -type f -name "*.html" | sudo xargs -I {} \
        java -jar $TO/htmlcompressor-0.9.8.jar --type html --remove-intertag-spaces --compress-js --nomunge -o {} {}
        # --remove-intertag-spaces  --remove-quotes (mgatto: "yuck!")
}
minify_css() {
    echo "Minifying CSS files"
    find ./$VERSION -type f -name "*.css" | sudo xargs -I {} \
        java -jar $TO/yuicompressor-2.4.4.jar --type css {} -o {} --charset utf-8  #--line-break 0
}
minify_js() {
    echo "Minifying Javascript files"
    find ./$VERSION -type f \( -name "*.js" \) | sudo xargs -I {} \
        java -jar $TO/yuicompressor-2.4.4.jar --type js {} -o {} --charset utf-8  #--line-break 0
}

# Optimize PNG file in place
# More information on PNG optimization techniques:
# http://optipng.sourceforge.net/pngtech/optipng.html
do_png () {
  # $1 is filename

  # advpng, part of AdvanceCOMP, is available here:
  # http://advancemame.sourceforge.net/comp-download.html
  #advpng -z -4 -q "$1"

  # OptiPNG is available here:
  # http://optipng.sourceforge.net/
  optipng -q -zc1-9 -zm1-9 -zs0-3 -f0-5 "$1"

  # pngout is available here (binaries only):
  # http://www.jonof.id.au/index.php?p=kenutils
  # pngout "$1" $TMPF -q -y
  # Sometimes (not always) pngout appends ".PNG" to output filename
  if [ -f "$TMPF.PNG" ]; then
    mv -f $TMPF.PNG $TMPF
  fi

  return 0
}

# Optimize JPEG file in place
# (edit here to add/remove JPEG optimizing steps or change parameters)
do_jpeg () {
  # $1 is filename
  TMPJ=$(mktemp -t -p $TMP tmp.XXXXXX) || return 1

  # jpegtran is part of libjpeg (almost surely already on your system).
  # If not, it's here:
  # http://www.ijg.org/
  jpegtran -copy none -optimize -outfile $TMPJ "$1" && mv -f $TMPJ "$1"

  # jfifremove is included with this script, be sure to compile and install
  # jfifremove < "$1" > $TMPJ && mv -f $TMPJ "$1"

  return 0
}

# Optimize file, only replace original if optimized version is smaller
do_file () {
  TMPF=$(mktemp -t -p $TMP tmp.XXXXXX) || exit 1
  # $1 is name of file
  if [ -w "$1" ]; then
    # Copy file to tmp file and optimize in place
    cp -f "$1" $TMPF
    case "$1" in
      *.[Pp][Nn][Gg] )
          do_png $TMPF
          ;;
      *.[Jj][Pp][Ee][Gg] )
          do_jpeg $TMPF
          ;;
      *.[Jj][Pp][Gg] )
      do_jpeg $TMPF
          ;;
          * )
      echo "$1 could not be identified, please rename to .jpg or .png"
      return 1
      ;;
    esac

    # If optimized file is smaller, copy it over original
    BEFORE=`ls -la "$1" | awk '{print $5}'`
    AFTER=`ls -la $TMPF | awk '{print $5}'`
    let REDUCED=$BEFORE-$AFTER
    if [ $AFTER -lt $BEFORE ]; then
      cp -f $TMPF $1
      echo "$1 reduced $REDUCED bytes to $AFTER bytes"
    else
      echo "$1 unchanged at $BEFORE bytes"
    fi

    return 0
  else
    echo "$1 is not writable, skipping"
    return 1
  fi
}

optimize_img() {
    find ./$VERSION -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) -print | while read i; do do_file "$i"; done
}

error() {
    echo $1
    exit 1
}

#version() {}

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

## Check for values:
echo "Checking for inputs"

#We *always* need $VERSION
if [ -z $VERSION ]; then
    read -p "Which version are we deploying?" VERSION || exit 1;
    #error "You must specify a version to deploy"
    #exit 1
fi

if [ -z $TO ]; then
    error "You must specify a destination to deploy to"
    exit 1
fi

if [ -z $DOMAIN ]; then
    error "You must specify a domain for which you are deploying"
    exit 1
fi

if [ -z $FROM ]; then
    error "You must specify a source to deploy from"
    exit 1
else
    # We must have either SVN & REPOSITORY or ZIP and ARCHIVE
    echo "$FROM"

    if [ "$FROM" == "svn" ]; then
        SVN=1 ;
        if [ -z $REPOSITORY ]; then
            error "You must specify a repository when deploying from Subversion"
        fi
    elif [ "$FROM" == "zip" ]; then
        ZIP=1 ;
        if [ -z $ARCHIVE ]; then
            error "You must specify a Zip archive file to deploy from"
        fi
    else
        echo "From target not specified" ;
        exit 1
    fi
fi

# if conf, we don't need others

echo "Preparing to build."
echo "Current Directory: $PWD"
echo "Changing to: $TO"
cd "$TO"

# does the VERSION dir already exist?
if [ -d "$VERSION" ]; then
    echo "Version: $VERSION already exists."
    read -p "Delete it?" DELETE

    case $DELETE in
        [Yy]* )
            rm -rf "./$VERSION" ;
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
if [ "$ZIP" == 1 ]; then
    if [ -n "$ARCHIVE" ]; then
        get_from_zip $ARCHIVE
    else
        echo "No archive for unzip was specified"
    fi
elif [ "$SVN" == 1 ]; then
    if [ -n "$REPOSITORY" ]; then
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
if [ -n "$REWRITE" ]; then
    rewrite_links $REWRITE
fi

# Shall we minify js or css, or both? Images, too?
# This should always come after Rewriting of links, if any.
#if [ "$COMBINE" != "no" ]; then
#    combine $COMBINE
#fi

cleanup_files
echo "Minifying HTML, CSS & JS fles"
minify_js
minify_css
minify_html
echo "Optimizing PMGs & JPGs"
optimize_img

# symlink must come before set_owner_and_group so the htdocs symlink ist't stuck as owned by root
symlink
set_owner_and_group www-data www-data

# or
# TMPDIR=$(mktemp -d)
#trap 'rm -rf "$TMPDIR"' EXIT

# clean up temp
if [ -d $TO/$TMP/ ]; then
    rm -rf $TO/$TMP/*
fi

echo "Deployed!"