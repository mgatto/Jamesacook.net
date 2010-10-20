#! /bin/bash -x

# must be run as root
if [ ! "`whoami`" = "root" ]
then
    echo "\nPlease run script as root."
    exit 1
fi

echo "Preparing to build."
echo "Current Directory: $PWD"

read -p "Do you wish to change dir?" YN
case $YN in
    [Yy]* ) read -p "To which path?" PATH; chdir $PATH ;;
    [Nn]* )  ;;
    * ) echo "Please answer yes or no.";;
esac

read -p "Which version are we deploying?" VERSION

# does the VERSION dir already exist?
if [ -d "./$VERSION" ];
then
    echo "Version: $VERSION already exists."

    read -p "Delete it?" DELETE
    case $DELETE in
        [Yy]* ) rm -rf "./$VERSION" ;;
        [Nn]* )  ;;
        * ) echo "Please answer yes or no.";;
    esac
fi

# check signature; gpg returns 0 if all is well, 1 for bad sig.
echo "Checking signature of Jamesacook.net-$VERSION.zip"
if [ $(gpg --verify Jamesacook.net-$VERSION.zip.sig Jamesacook.net-$VERSION.zip) -ne 0 ];
then
  echo "Signature verification failed!"
  exit 1
fi

#unzip it; -a converts windows EOL -> UNIX; but, it thinks jpg and flv are text
unzip "Jamesacook.net-$VERSION.zip" -d ./

# its easier (?) to do further operations inside
cd "$VERSION"

#delete .svn & _notes dirs
find . -name ".svn" -type d -exec rm -rf {} \;
find . -name "_notes" -type d -exec rm -rf {} \;

#find . -name ".svn" -type d | xargs -n1 rm -R

# Delete Templates, Library and Build
rm -rf ./Templates
rm -rf ./Library
rm -rf ./Build

# strip all comments and rewrite links if necessary
echo "rewriting links, excluding binary files"
find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) | xargs sed -i \
        -e 's|href=\"/|href=\"/jamesacook.net/|g' \
        -e 's|src=\"/|src=\"/jamesacook.net/|g' \
        -e "s|url('/|url('/jamesacook.net/|g" \
        -e "s|url(/|url(/jamesacook.net/|g" \
        -e "s|uri = \"/|uri = \"/jamesacook.net/|g" \
        -e "s|src: '|src: '/jamesacook.net/media/|g" \
        -e "s|url: '|url: '/jamesacook.net/media/|g" \
        -e "s|<!--(.*?)-->||g";

# reverse the link rewriting...
#find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.js" \) | xargs sed -i \
#        -e 's|href=\"/jamesacook.net/|href=\"/|g' \
#        -e 's|src=\"/jamesacook.net/|src=\"/|g' \
#        -e "s|url('/jamesacook.net/|url('/|g" \
#        -e "s|url(/jamesacook.net/|url(/|g" \
#        -e "s|uri = \"/jamesacook.net/|uri = \"/|g" \
#        -e "s|src: '/jamesacook.net/media/|src: '|g" \
#        -e "s|url: '/jamesacook.net/media/|url: '|g";

# this is one reason this script needs to be run as root
chown www-data:www-data . -R

cd ..

echo "Symlinking"
# symlink htdocs
ln -sfn $VERSION htdocs

echo "Deployed!"