# ------------------
# enblend 4.0   
# ------------------
# $Id: enblend3.sh 1908 2007-02-05 14:59:45Z ippei $
# Copyright (c) 2007, Ippei Ukai

# prepare

# export REPOSITORYDIR="/PATH2HUGIN/mac/ExternalPrograms/repository" \
# ARCHS="ppc i386" \
#  ppcTARGET="powerpc-apple-darwin7" \
#  i386TARGET="i386-apple-darwin8" \
#  ppcMACSDKDIR="/Developer/SDKs/MacOSX10.3.9.sdk" \
#  i386MACSDKDIR="/Developer/SDKs/MacOSX10.4u.sdk" \
#  ppcONLYARG="-mcpu=G3 -mtune=G4" \
#  i386ONLYARG="-mfpmath=sse -msse2 -mtune=pentium-m -ftree-vectorize" \
#  ppc64ONLYARG="-mcpu=G5 -mtune=G5 -ftree-vectorize" \
#  OTHERARGs="";

# -------------------------------
# 20091206.0 sg Script tested and used to build 2009.4.0-RC3
# 20091209.0 sg Script enhanced to build Enblemd-Enfuse 4.0
# 20091210.0 hvdw Removed code that downgraded optimization from -O3 to -O2
# 20091223.0 sg Added argument to configure to locate missing TTF
#               Building enblend documentation requires tex. Check if possible.
# 20100402.0 hvdw Adapt to build openmp enabled versions. Needs the Setenv-leopard-openmp.txt file
# -------------------------------

# init

# Fancy doc builds on Enblend 3.2 are doomed to failure, so don't even try...
AC_INIT=$(grep AC_INIT Configure.in)
TEX=$(which tex)

# If NOT 3.2 and if tex is installed, and if FreeSans.ttf is in the right place...
if [ -z "$(echo $AC_INIT|grep 3.2,)" ] && \
    [ -n "$TEX" ]  && [ -f "/Users/$LOGNAME/Library/Fonts/FreeSans.ttf" ]; then 
    buildDOC="yes"
    extraConfig="--with-ttf-path=/Users/$LOGNAME/Library/Fonts --enable-split-doc=no"
    extraBuild="ps pdf xhtml"
    extraInstall="install-ps install-pdf install-xhtml"
else
    buildDOC="no"
    extraConfig=""
    extraBuild=""
    extraInstall=""
fi 

let NUMARCH="0"

for i in $ARCHS
do
    NUMARCH=$(($NUMARCH + 1))
done

mkdir -p "$REPOSITORYDIR/bin";
mkdir -p "$REPOSITORYDIR/lib";
mkdir -p "$REPOSITORYDIR/include";

# compile

for ARCH in $ARCHS
do
    mkdir -p "$REPOSITORYDIR/arch/$ARCH/bin";
    mkdir -p "$REPOSITORYDIR/arch/$ARCH/lib";
    mkdir -p "$REPOSITORYDIR/arch/$ARCH/include";
    
    ARCHARGs=""
    MACSDKDIR=""
    
    if [ $ARCH = "i386" -o $ARCH = "i686" ] ; then
	TARGET=$i386TARGET
	MACSDKDIR=$i386MACSDKDIR
	ARCHARGs="$i386ONLYARG"
	OSVERSION="$i386OSVERSION"
	CC=$i386CC
	CXX=$i386CXX
    elif [ $ARCH = "x86_64" ] ; then
	TARGET=$x64TARGET
	MACSDKDIR=$x64MACSDKDIR
	ARCHARGs="$x64ONLYARG"
	OSVERSION="$x64OSVERSION"
	CC=$x64CC
	CXX=$x64CXX
    fi
    
    # To build documentation, you will need to install the following (port) packages:
    #   freefont-ttf
    #   gnuplot
    #   ghostscript
    #   texi2html
    #   transfig
    #   tidy
    #  *teTeX
    # This script presumes you have installed the fonts in ~/Library/Fonts. 
    # See <http://trac.macports.org/ticket/16938> for how to do this.
    # (Port installs the fonts here: /opt/local/share/fonts/freefont-ttf/)
    # The port version of teTeX did not install cleanly for me. Instead, I downloaded a pre-built distro
    # called MacTeX <http://www.tug.org/mactex/2009/>. After installing, you will need to add this
    # directory to your PATH, as shown on the next line: 
    # export PATH=/usr/local/texlive/2009/bin/universal-darwin:$PATH
    # To make the change permanent, edit ~/.profile.

    env \
	CC=$CC CXX=$CXX \
	CFLAGS="-fopenmp -isysroot $MACSDKDIR -I$REPOSITORYDIR/include -arch $ARCH $ARCHARGs $OTHERARGs -dead_strip" \
	CXXFLAGS="-fopenmp -isysroot $MACSDKDIR -I$REPOSITORYDIR/include -arch $ARCH $ARCHARGs $OTHERARGs -dead_strip" \
	CPPFLAGS="-fopenmp -I$REPOSITORYDIR/include -I$REPOSITORYDIR/include/OpenEXR -I/usr/include" \
	LIBS="-lGLEW -framework GLUT -lobjc -framework OpenGL -framework AGL" \
	LDFLAGS="-L$REPOSITORYDIR/lib -L/usr/lib -mmacosx-version-min=$OSVERSION -dead_strip" \
	NEXT_ROOT="$MACSDKDIR" \
	PKG_CONFIG_PATH="$REPOSITORYDIR/lib/pkgconfig" \
	./configure --prefix="$REPOSITORYDIR" --disable-dependency-tracking \
	--host="$TARGET" --exec-prefix=$REPOSITORYDIR/arch/$ARCH --with-apple-opengl-framework \
	--disable-image-cache --enable-openmp=yes --disable-gpu-support \
	--with-glew $extraConfig --with-openexr || fail "configure step for $ARCH"
    
    # hack; AC_FUNC_MALLOC sucks!!
    # mv ./config.h ./config.h-copy; 
    # sed -e 's/HAVE_MALLOC\ 0/HAVE_MALLOC\ 1/' \
    #     -e 's/rpl_malloc/malloc/' \
    #     "./config.h-copy" > "./config.h";

    # Default to standard -O3 optimization as this improves performance
    # and shrinks the binary
    # If you prefer -O2, change -O3 to -O2 in the 3rd line (containing the sed command).
    [ -f src/Makefile.bak ] && rm src/Makefile.bak
    mv src/Makefile src/Makefile.bak
    sed -e "s/-O[0-9]/-O3/g" "src/Makefile.bak" > src/Makefile
    
    make clean;
    make all $extraBuild ;
    make install $extraInstall ;
done


# merge execs
for program in bin/enblend bin/enfuse
do
    if [ $NUMARCH -eq 1 ] ; then
	if [ -f $REPOSITORYDIR/arch/$ARCHS/$program ] ; then
	    echo "Moving arch/$ARCHS/$program to $program"
  	    mv "$REPOSITORYDIR/arch/$ARCHS/$program" "$REPOSITORYDIR/$program";
  	    strip -x "$REPOSITORYDIR/$program";
  	    continue
	else
	    echo "Program arch/$ARCHS/$program not found. Aborting build";
	    exit 1;
	fi
    fi
    
    LIPOARGs=""
    
    for ARCH in $ARCHS
    do
 	if [ -f $REPOSITORYDIR/arch/$ARCH/$program ] ; then
	    echo "Adding arch/$ARCH/$program to bundle"
 	    LIPOARGs="$LIPOARGs $REPOSITORYDIR/arch/$ARCH/$program"
	else
	    echo "File arch/$ARCH/$program was not found. Aborting build";
	    exit 1;
	fi
    done
    
    lipo $LIPOARGs -create -output "$REPOSITORYDIR/$program";
    strip -x "$REPOSITORYDIR/$program";
done
