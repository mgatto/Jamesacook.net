#! /bin/bash
echo "Preparing to build in $PWD"
echo -n "Do you wish to change dir?"
read YN
case $YN in
    [Yy]* ) read -p "To which path?" PATH; chdir $PATH; break;;
    [Nn]* ) break;;
    * ) echo "Please answer yes or no.";;
esac

echo -n "Which version are we deploying"
read VERSION

# check md5sum
echo "Checking signature of Jamesacook.net-$VERSION.zip"
if [ ! $(gpg --verify Jamesacook.net-$VERSION.zip.sig Jamesacook.net-$VERSION.zip) ];
then
  echo "Signature verification failed!"
  exit 1
fi

#untar it
unzip "Jamesacook.net-$VERSION.zip" -d ./

# its easier (?) to do further operations inside
cd "$VERSION"

#delete .svn dirs
find . -name ".svn" -type d -exec rm -rf {} \;
#find . -name ".svn" -type d | xargs -n1 rm -R

# Delete Templates, Library and Build
rm -rf ./Templates
rm -rf ./Library
rm -rf ./Build

# rewrite links if necessary
echo "rewriting links"
for FILE in $(ls -R .)
do
    echo
    #sed -i \
    #    -e s/href=\"\//href=\"\/jamesacook.net\//g \
    #    -e s/src=\"\//src=\"\/jamesacook.net\//g \
    #    -e s/src=\"\//src=\"\/jamesacook.net\//g \
    #    -e s/url(\'\//url(\'\/jamesacook.net\//g \
    #    -e s/url(\//url(\/jamesacook.net\//g \
    #    -e s/url(\//url(\/jamesacook.net\//g \
    #    -e s/url = \"\//url = \"\/jamesacook.net\//g \
    #    -e s/src: \'\/media/src: \'\/jamesacook\/media/g \
    #    -e s/url: \'\/media/url: \'\/jamesacook\/media/g \
    $FILE
done

cd ..

echo "Symlinking"
# symlink htdocs
ln -sf htdocs $VERSION

ls -la