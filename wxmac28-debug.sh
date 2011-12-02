# ------------------
#     wxMac 2.8
# ------------------
# $Id: wxmac28.sh 1902 2007-02-04 22:27:47Z ippei $
# Copyright (c) 2007, Ippei Ukai


# prepare
source ../scripts/functions.sh
check_SetEnv

# -------------------------------
# 20091206.0 sg Script NOT tested but adapted from script used to build 2009.4.0-RC3
#               The non-debug version works onnl: 10.5, 10.6 & Powerpc 10.4, 10.5
# -------------------------------

# init

uname_release=$(uname -r)
uname_arch=$(uname -p)
[ $uname_arch = powerpc ] && uname_arch="ppc"
os_dotvsn=${uname_release%%.*}
os_dotvsn=$(($os_dotvsn - 4))
case $os_dotvsn in
 4 ) os_sdkvsn="10.4u" ;;
 5|6 ) os_sdkvsn=10.$os_dotvsn ;;
 * ) echo "Unhandled OS Version: 10.$os_dotvsn. Build aborted."; exit 1 ;;
esac

NATIVE_SDKDIR="/Developer/SDKs/MacOSX$os_sdkvsn.sdk"
NATIVE_OSVERSION="10.$os_dotvsn"
NATIVE_ARCH=$uname_arch
NATIVE_OPTIMIZE=""

# Toolkit Choice, default choice is mac (i.e. carbon, 32bit only)
TOOLKIT="mac"
if [ $# -eq 1 ]; then
    if [ "$1" = "cocoa" ]; then
	TOOLKIT="cocoa"
    elif [ "$1" = "mac" ]; then
	TOOLKIT="mac"
    fi
fi

# patch for Snow Leopard
thisarch=$(uname -m)
if [ "$thisarch" = x86_64 ] ; then
	patch -Np1 < ../scripts/wxMac-2.8.10.patch
fi

WXVERSION="2.8"
WXVER_COMP="$WXVERSION.0"
#WXVER_FULL="$WXVER_COMP.5.0"  # for 2.8.8
WXVER_FULL="$WXVER_COMP.8.0"  # for 2.8.12

mkdir -p "$REPOSITORYDIR/bin";
mkdir -p "$REPOSITORYDIR/lib";
mkdir -p "$REPOSITORYDIR/include";

# compile
let NUMARCH="0"
if [ "$TOOLKIT" = "mac" ]; then
    remove_64bits_from_ARCH
fi

for ARCH in $ARCHS
do
    mkdir -p "osx-$ARCH-build";
    cd "osx-$ARCH-build";
    
    mkdir -p "$REPOSITORYDIR/arch/$ARCH/bin";
    mkdir -p "$REPOSITORYDIR/arch/$ARCH/lib";
    mkdir -p "$REPOSITORYDIR/arch/$ARCH/include";
    
    ARCHARGs=""
    MACSDKDIR=""
    
    compile_setenv

    if [ "$TOOLKIT" = "cocoa" ]; then
	withToolkit="--with-cocoa"
    else
	withToolkit="--with-mac"
    fi
 
    env \
	CC=$CC CXX=$CXX \
	CFLAGS="-isysroot $MACSDKDIR -arch $ARCH $ARCHARGs $OTHERARGs -O2 -g -dead_strip" \
	CXXFLAGS="-isysroot $MACSDKDIR -arch $ARCH $ARCHARGs $OTHERARGs -O2 -g -dead_strip" \
	CPPFLAGS="-isysroot $MACSDKDIR -arch $ARCH $ARCHARGs $OTHERARGs -O2 -g -dead_strip -I$REPOSITORYDIR/include" \
	OBJCFLAGS="-arch $ARCH" \
	OBJCXXFLAGS="-arch $ARCH" \
	LDFLAGS="-L$REPOSITORYDIR/lib -arch $ARCH -mmacosx-version-min=$OSVERSION -g -dead_strip -prebind" \
	../configure --prefix="$REPOSITORYDIR" --exec-prefix=$REPOSITORYDIR/arch/$ARCH $withToolkit \
	--disable-dependency-tracking \
	--host="$TARGET" --with-macosx-sdk=$MACSDKDIR --with-macosx-version-min=$OSVERSION \
	--enable-monolithic --enable-unicode --with-opengl --disable-compat26 --disable-graphics_ctx \
	--enable-shared --enable-debug --enable-debugreport;
    
    ### Setup.h is created by configure!
    # For all SDK; CP panel problem still exists.
    ## disable core graphics implementation for 10.3
    #if [[ $TARGET == *darwin7 ]]
    #then
    # need to find out where setup.h was created. This seems to vary if building on powerpc and
    # is different under 10.4 and 10.5
    whereIsSetup=$(find . -name setup.h -print)
    whereIsSetup=${whereIsSetup#./}
    echo '#ifndef wxMAC_USE_CORE_GRAPHICS'    >> $whereIsSetup
    echo ' #define wxMAC_USE_CORE_GRAPHICS 0' >> $whereIsSetup
    echo '#endif'                             >> $whereIsSetup
    echo ''                                   >> $whereIsSetup
    #fi
    make clean;

    #hack
    cp utils/wxrc/Makefile utils/wxrc/Makefile-copy;
    echo "all: " > utils/wxrc/Makefile;
    echo "" >> utils/wxrc/Makefile;
    echo "install: " >> utils/wxrc/Makefile;
    #~hack

    case $NATIVE_OSVERSION in
	10.4 )
	    dylib_name="dylib1.o"
	    ;;
	10.5 | 10.6 )
	    dylib_name="dylib1.10.5.o"
	    ;;
	* )
	    echo "OS Version $NATIVE_OSVERSION not supported"; exit 1
		 ;;
    esac
    cp $NATIVE_SDKDIR/usr/lib/$dylib_name $REPOSITORYDIR/lib/
    
    # Need to build single-threaded. libwx_macu-2.8.dylib needs to be built before libwx_macu_gl-2.8 to avoid a link error.
    # This is only problematic for Intel builds, where jobs can be >1
    make --jobs=1;
    make install;
    
    rm $REPOSITORYDIR/lib/$dylib_name;
    
    cd ../;
done


# merge libwx
echo "merging libraries"
for liba in lib/libwx_"$TOOLKIT"ud-$WXVER_FULL.dylib lib/libwx_"$TOOLKIT"ud_gl-$WXVER_FULL.dylib
do
    if [ $NUMARCH -eq 1 ] ; then
	if [ -f $REPOSITORYDIR/arch/$ARCHS/$liba ] ; then
	    echo "Moving arch/$ARCHS/$liba to $liba"
  	    mv "$REPOSITORYDIR/arch/$ARCHS/$liba" "$REPOSITORYDIR/$liba";
	   #Power programming: if filename ends in "a" then ...
	    [ ${liba##*.} = a ] && ranlib "$REPOSITORYDIR/$liba";
  	    continue
	else
	    echo "Program arch/$ARCHS/$liba not found. Aborting build";
	    exit 1;
	fi
    fi
    
    LIPOARGs=""
    for ARCH in $ARCHS
    do
	if [ -f $REPOSITORYDIR/arch/$ARCH/$liba ] ; then
	    echo "Adding arch/$ARCH/$liba to bundle"
	    LIPOARGs="$LIPOARGs $REPOSITORYDIR/arch/$ARCH/$liba"
	else
	    echo "File arch/$ARCH/$liba was not found. Aborting build";
	    exit 1;
	fi
    done
    
    lipo $LIPOARGs -create -output "$REPOSITORYDIR/$liba";
done

if [ -f "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud-$WXVER_FULL.dylib ] ; then
    install_name_tool \
	-id "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud-"$WXVER_COMP".dylib \
	"$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud-"$WXVER_FULL".dylib;
    ln -sfn libwx_"$TOOLKIT"ud-"$WXVER_FULL".dylib "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud-"$WXVER_COMP".dylib;
    ln -sfn libwx_"$TOOLKIT"ud-"$WXVER_FULL".dylib "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud-"$WXVERSION".dylib;
fi
if [ -f "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud_gl-"$WXVER_FULL".dylib ] ; then
  install_name_tool \
      -id "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud_gl-"$WXVER_COMP".dylib \
      "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud_gl-"$WXVER_FULL".dylib;
  for ARCH in $ARCHS
  do
      install_name_tool \
	  -change "$REPOSITORYDIR"/arch/"$ARCH"/lib/libwx_"$TOOLKIT"ud-"$WXVER_COMP".dylib \
          "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud-"$WXVER_COMP".dylib \
          "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud_gl-"$WXVER_FULL".dylib;
  done
  ln -sfn libwx_"$TOOLKIT"ud_gl-"$WXVER_FULL".dylib "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud_gl-"$WXVER_COMP".dylib;
  ln -sfn libwx_"$TOOLKIT"ud_gl-"$WXVER_FULL".dylib "$REPOSITORYDIR"/lib/libwx_"$TOOLKIT"ud_gl-"$WXVERSION".dylib;
fi

# merge setup.h
echo "merging setup.h"
for dummy in "wx/setup.h"
do
    wxmacconf=lib/wx/include/"$TOOLKIT"-unicode-debug-$WXVERSION/wx/setup.h
    
    mkdir -p $(dirname "$REPOSITORYDIR/$wxmacconf")
    echo ""  >$REPOSITORYDIR/$wxmacconf
    
    if [ $NUMARCH -eq 1 ] ; then
	ARCH=$ARCHS
	pushd $REPOSITORYDIR
	whereIsSetup=$(find ./arch/$ARCH/lib/wx -name setup.h -print | grep debug | grep $TOOLKIT | head -1)
	whereIsSetup=${whereIsSetup#./arch/*/}
	popd 
	cat "$REPOSITORYDIR/arch/$ARCH/$whereIsSetup" >>"$REPOSITORYDIR/$wxmacconf";
	continue
    fi
    
    for ARCH in $ARCHS
    do
	
 	pushd $REPOSITORYDIR
 	whereIsSetup=$(find ./arch/$ARCH/lib/wx -name setup.h -print | grep debug | grep $TOOLKIT | head -1)
 	whereIsSetup=${whereIsSetup#./arch/*/}
 	popd 
	
	if [ $ARCH = "i386" -o $ARCH = "i686" ] ; then
	    echo "#if defined(__i386__)"                       >> "$REPOSITORYDIR/$wxmacconf";
	    echo ""                                            >> "$REPOSITORYDIR/$wxmacconf";
	    cat "$REPOSITORYDIR/arch/$ARCH/$whereIsSetup"      >> "$REPOSITORYDIR/$wxmacconf";
	    echo ""                                            >> "$REPOSITORYDIR/$wxmacconf";
	    echo "#endif"                                      >> "$REPOSITORYDIR/$wxmacconf";
	elif [ $ARCH = "ppc" -o $ARCH = "ppc750" -o $ARCH = "ppc7400" ] ; then
	    echo "#if defined(__ppc__) || defined(__ppc64__)"  >> "$REPOSITORYDIR/$wxmacconf";
	    echo ""                                            >> "$REPOSITORYDIR/$wxmacconf";
	    cat "$REPOSITORYDIR/arch/$ARCH/$whereIsSetup"      >> "$REPOSITORYDIR/$wxmacconf";
	    echo ""                                            >> "$REPOSITORYDIR/$wxmacconf";
	    echo "#endif"                                      >> "$REPOSITORYDIR/$wxmacconf";
	elif [ $ARCH = "x86_64" ] ; then
	    echo "#if defined(__x86_64__) "                    >> "$REPOSITORYDIR/$wxmacconf";
	    echo ""                                            >> "$REPOSITORYDIR/$wxmacconf";
	    cat "$REPOSITORYDIR/arch/$ARCH/$whereIsSetup"      >> "$REPOSITORYDIR/$wxmacconf";
	    echo ""                                            >> "$REPOSITORYDIR/$wxmacconf";
	    echo "#endif"                                      >> "$REPOSITORYDIR/$wxmacconf";
	else
	    echo "Unhandled ARCH: $ARCH. Aborting build."; exit 1
	fi
    done
    
done

#wx-config
echo "modifying wx-config"
for ARCH in $ARCHS
do
    sed -e 's/^exec_prefix.*$/exec_prefix=\$\{prefix\}/' \
	-e 's/-arch '$ARCH'//' \
      $REPOSITORYDIR/arch/$ARCH/bin/wx-config > $REPOSITORYDIR/bin/wx-config
    break;
done
