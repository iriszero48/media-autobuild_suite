#!/bin/bash
# shellcheck disable=SC2034,SC1090,SC1117,SC1091,SC2119
export http_proxy=http://127.0.0.1:7890; export https_proxy=http://127.0.0.1:7890;
shopt -s extglob

if [[ -z $LOCALBUILDDIR ]]; then
    printf '%s\n' \
        "Something went wrong." \
        "MSYSTEM: $MSYSTEM" \
        "pwd: $(cygpath -w "$(pwd)")" \
        "fstab: " \
        "$(cat /etc/fstab)" \
        "Create a new issue and upload all logs you can find, especially compile.log"
    read -r -p "Enter to continue" ret
    exit 1
fi
FFMPEG_BASE_OPTS=("--pkg-config=pkgconf" --pkg-config-flags="--keep-system-libs --keep-system-cflags --static" "--cc=$CC" "--cxx=$CXX" "--ld=$CXX" "--extra-cxxflags=-fpermissive" "--extra-cflags=-Wno-int-conversion")
printf '\nBuild start: %(%F %T %z)T\n' -1 >> "$LOCALBUILDDIR/newchangelog"

printf '#!/bin/bash\nbash %s %s\n' "$LOCALBUILDDIR/media-suite_compile.sh" "$*" > "$LOCALBUILDDIR/last_run"

while true; do
    case $1 in
    --cpuCount=* ) cpuCount=${1#*=} && shift ;;
    --build32=* ) build32=${1#*=} && shift ;;
    --build64=* ) build64=${1#*=} && shift ;;
    --mp4box=* ) mp4box=${1#*=} && shift ;;
    --rtmpdump=* ) rtmpdump=${1#*=} && shift ;;
    --vpx=* ) vpx=${1#*=} && shift ;;
    --x264=* ) x264=${1#*=} && shift ;;
    --x265=* ) x265=${1#*=} && shift ;;
    --other265=* ) other265=${1#*=} && shift ;;
    --flac=* ) flac=${1#*=} && shift ;;
    --fdkaac=* ) fdkaac=${1#*=} && shift ;;
    --mediainfo=* ) mediainfo=${1#*=} && shift ;;
    --sox=* ) sox=${1#*=} && shift ;;
    --ffmpeg=* ) ffmpeg=${1#*=} && shift ;;
    --ffmpegUpdate=* ) ffmpegUpdate=${1#*=} && shift ;;
    --ffmpegPath=* ) ffmpegPath="${1#*=}"; shift ;;
    --ffmpegChoice=* ) ffmpegChoice=${1#*=} && shift ;;
    --mplayer=* ) mplayer=${1#*=} && shift ;;
    --mpv=* ) mpv=${1#*=} && shift ;;
    --deleteSource=* ) deleteSource=${1#*=} && shift ;;
    --license=* ) license=${1#*=} && shift ;;
    --standalone=* ) standalone=${1#*=} && shift ;;
    --stripping* ) stripping=${1#*=} && shift ;;
    --packing* ) packing=${1#*=} && shift ;;
    --logging=* ) logging=${1#*=} && shift ;;
    --bmx=* ) bmx=${1#*=} && shift ;;
    --aom=* ) aom=${1#*=} && shift ;;
    --faac=* ) faac=${1#*=} && shift ;;
    --exhale=* ) exhale=${1#*=} && shift ;;
    --ffmbc=* ) ffmbc=${1#*=} && shift ;;
    --curl=* ) curl=${1#*=} && shift ;;
    --cyanrip=* ) cyanrip=${1#*=} && shift ;;
    --ripgrep=* ) ripgrep=${1#*=} && shift ;;
    --rav1e=* ) rav1e=${1#*=} && shift ;;
    --dav1d=* ) dav1d=${1#*=} && shift ;;
    --libavif=* ) libavif=${1#*=} && shift ;;
    --jpegxl=* ) jpegxl=${1#*=} && shift ;;
    --vvc=* ) vvc=${1#*=} && shift ;;
    --uvg266=* ) uvg266=${1#*=} && shift ;;
    --vvenc=* ) vvenc=${1#*=} && shift ;;
    --vvdec=* ) vvdec=${1#*=} && shift ;;
    --jq=* ) jq=${1#*=} && shift ;;
    --jo=* ) jo=${1#*=} && shift ;;
    --dssim=* ) dssim=${1#*=} && shift ;;
    --avs2=* ) avs2=${1#*=} && shift ;;
    --timeStamp=* ) timeStamp=${1#*=} && shift ;;
    --noMintty=* ) noMintty=${1#*=} && shift ;;
    --ccache=* ) ccache=${1#*=} && shift ;;
    --svthevc=* ) svthevc=${1#*=} && shift ;;
    --svtav1=* ) svtav1=${1#*=} && shift ;;
    --svtvp9=* ) svtvp9=${1#*=} && shift ;;
    --xvc=* ) xvc=${1#*=} && shift ;;
    --vlc=* ) vlc=${1#*=} && shift ;;
    # --autouploadlogs=* ) autouploadlogs=${1#*=} && shift ;;
    -- ) shift && break ;;
    -* ) echo "Error, unknown option: '$1'." && exit 1 ;;
    * ) break ;;
    esac
done

[[ $ccache != y ]] && export CCACHE_DISABLE=1

source "$LOCALBUILDDIR"/media-suite_deps.sh

# shellcheck source=media-suite_helper.sh
source "$LOCALBUILDDIR"/media-suite_helper.sh

do_simple_print -p "${orange}Warning: We will not accept any issues lacking any form of logs or logs.zip!$reset"

buildProcess() {
set_title
do_simple_print -p '\n\t'"${orange}Starting $bits compilation of all tools$reset"
[[ -f $HOME/custom_build_options ]] &&
    echo "Imported custom build options (unsupported)" &&
    source "$HOME"/custom_build_options

cd_safe "$LOCALBUILDDIR"

do_getFFmpegConfig "$license"
do_getMpvConfig

# in case the root was moved, this fixes windows abspaths
mkdir -p "$LOCALDESTDIR/lib/pkgconfig"
# pkgconfig keys to find the wrong abspaths from
local _keys="(prefix|exec_prefix|libdir|includedir)"
# current abspath root
local _root
_root=$(cygpath -m "$LOCALDESTDIR")
# find .pc files with Windows abspaths
grep -ElZR "${_keys}=[^/$].*" "$LOCALDESTDIR"/lib/pkgconfig | \
    # find those with a different abspath than the current
    xargs -0r grep -LZ "$_root" | \
    # replace with current abspath
    xargs -0r sed -ri "s;${_keys}=.*$LOCALDESTDIR;\1=$_root;g"
unset _keys _root

_clean_old_builds=(j{config,error,morecfg,peglib}.h
    lib{jpeg,nettle,ogg,vorbis{,enc,file},gnurx,regex}.{,l}a
    lib{opencore-amr{nb,wb},twolame,theora{,enc,dec},caca,magic,uchardet}.{l,}a
    libSDL{,main}.{l,}a libopen{jpwl,mj2,jp2}.{a,pc}
    include/{nettle,ogg,opencore-amr{nb,wb},theora,cdio,SDL,openjpeg-2.{1,2},luajit-2.0,uchardet,wels}
    regex.h magic.h
    {nettle,ogg,vorbis{,enc,file},vo-aacenc,sdl,uchardet}.pc
    {opencore-amr{nb,wb},twolame,theora{,enc,dec},caca,dcadec,libEGL,openh264}.pc
    libcdio_{cdda,paranoia}.{{l,}a,pc}
    share/aclocal/{ogg,vorbis}.m4
    twolame.h bin-audio/{twolame,cd-paranoia}.exe
    bin-global/{{file,uchardet}.exe,sdl-config,luajit-2.0.4.exe}
    libebur128.a ebur128.h
    libopenh264.a
    liburiparser.{{,l}a,pc}
    libchromaprint.{a,pc} chromaprint.h
    bin-global/libgcrypt-config libgcrypt.a gcrypt.h
    lib/libgcrypt.def bin-global/{dumpsexp,hmac256,mpicalc}.exe
    crossc.{h,pc} libcrossc.a
    include/onig{uruma,gnu,posix}.h libonig.a oniguruma.pc
)

do_uninstall q all "${_clean_old_builds[@]}"
unset _clean_old_builds

# In case a build was interrupted before reversing hide_conflicting_libs
[[ -d $LOCALDESTDIR/opt/cyanffmpeg ]] &&
    hide_conflicting_libs -R "$LOCALDESTDIR/opt/cyanffmpeg"
hide_conflicting_libs -R
do_hide_all_sharedlibs
create_ab_pkgconfig
create_cmake_toolchain
create_ab_ccache
pacman -S --noconfirm "$MINGW_PACKAGE_PREFIX-cmake" > /dev/null 2>&1

set_title "compiling global tools"
do_simple_print -p '\n\t'"${orange}Starting $bits compilation of global tools${reset}"

if [[ $packing = y &&
    ! "$(/opt/bin/upx -V 2> /dev/null | head -1)" = "upx 3.96" ]] &&
    do_wget -h 014912ea363e2d491587534c1e7efd5bc516520d8f2cdb76bb0aaf915c5db961 \
        "https://github.com/upx/upx/releases/download/v3.96/upx-3.96-win32.zip"; then
    do_install upx.exe /opt/bin/upx.exe
fi

_check=("$RUSTUP_HOME"/bin/rustup.exe)
if [[ $ripgrep = y || $rav1e = y || $dssim = y || $libavif = y ]] || enabled librav1e; then
    if ! files_exist "$RUSTUP_HOME"/bin/rustup.exe; then
        mkdir -p "$LOCALBUILDDIR/rustinstall"
        cd_safe "$LOCALBUILDDIR/rustinstall"
        log download_rustup "${curl_opts[@]}" "https://sh.rustup.rs" -So rustup.sh
        log install_rust ./rustup.sh -v -y --no-modify-path \
            "--default-host=${MSYSTEM_CARCH}-pc-windows-gnu" \
            --default-toolchain=stable
        do_checkIfExist
        hash -r
        add_to_remove
        cd_safe "$LOCALBUILDDIR"
    fi
    if ! [[ $(rustup toolchain list) =~ stable-$CARCH-pc-windows-gnu ]]; then
        # install current target arch toolchain
        log install_toolchain "$RUSTUP_HOME/bin/rustup.exe" toolchain \
            install "stable-$CARCH-pc-windows-gnu"
    fi
    log rustup_update "$RUSTUP_HOME/bin/rustup.exe" update
    log set_default_toolchain "$RUSTUP_HOME/bin/rustup.exe" default \
        "stable-$CARCH-pc-windows-gnu"
fi

_check=(bin-global/rg.exe)
if [[ $ripgrep = y ]] &&
    do_vcs "https://github.com/BurntSushi/ripgrep.git"; then
    do_uninstall "${_check[@]}"
    do_rust
    do_install "target/$CARCH-pc-windows-gnu/release/rg.exe" bin-global/
    do_checkIfExist
fi

_check=(bin-global/jo.exe)
if [[ $jo = y ]] &&
    do_vcs "https://github.com/jpmens/jo.git"; then
    do_mesoninstall global
    do_checkIfExist
fi

_deps=("$MINGW_PREFIX"/lib/pkgconfig/oniguruma.pc)
_check=(bin-global/jq.exe)
if [[ $jq = y ]] &&
    do_vcs "https://github.com/stedolan/jq.git"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/jq/0001-jv_thread-try-using-HAVE_PTHREAD_KEY_CREATE-instead.patch" am
    do_pacman_install oniguruma
    do_uninstall "${_check[@]}"
    do_autoreconf
    CFLAGS+=' -D_POSIX_C_SOURCE' YFLAGS='--warnings=no-yacc' \
        do_separate_conf global --enable-{all-static,pthread-tls} --disable-docs
    do_make && do_install jq.exe bin-global/
    do_checkIfExist
fi

_check=(bin-global/dssim.exe)
if [[ $dssim = y ]] &&
    do_vcs "https://github.com/kornelski/dssim.git"; then
    do_uninstall "${_check[@]}"
    CFLAGS+=" -fno-PIC" do_rust
    do_install "target/$CARCH-pc-windows-gnu/release/dssim.exe" bin-global/
    do_checkIfExist
fi

_check=(libxml2.a libxml2/libxml/xmlIO.h libxml-2.0.pc)
if { enabled_any libxml2 libbluray || [[ $cyanrip = y ]] || ! mpv_disabled libbluray; } &&
    do_vcs "$SOURCE_REPO_LIBXML2"; then
    do_uninstall include/libxml2/libxml "${_check[@]}"
    NOCONFIGURE=true do_autogen
    [[ -f config.mak ]] && log "distclean" make distclean
    sed -ri 's|(bin_PROGRAMS = ).*|\1|g' Makefile.am
    CFLAGS+=" -DLIBXML_STATIC_FOR_DLL -DNOLIBTOOL" \
        do_separate_confmakeinstall --without-python
    do_checkIfExist
fi

if [[ $ffmpeg != no ]] && enabled libaribb24; then
    _check=(libpng.{pc,{,l}a} libpng16.{pc,{,l}a} libpng16/png.h)
    if do_vcs "$SOURCE_REPO_LIBPNG"; then
        do_uninstall include/libpng16 "${_check[@]}"
        do_autoupdate
        do_separate_confmakeinstall --with-pic
        do_checkIfExist
    fi

    _deps=(libpng.{pc,a} libpng16.{pc,a})
    _check=(aribb24.pc libaribb24.{,l}a)
    if do_vcs "$SOURCE_REPO_ARRIB24"; then
        do_patch "https://raw.githubusercontent.com/BtbN/FFmpeg-Builds/master/patches/aribb24/12.patch"
        do_patch "https://raw.githubusercontent.com/BtbN/FFmpeg-Builds/master/patches/aribb24/13.patch"
        do_patch "https://raw.githubusercontent.com/BtbN/FFmpeg-Builds/master/patches/aribb24/17.patch"
        do_uninstall include/aribb24 "${_check[@]}"
        do_autoreconf
        do_separate_confmakeinstall --with-pic
        do_checkIfExist
    fi
fi

if [[ $mplayer = y || $mpv = y ]] ||
    { [[ $ffmpeg != no ]] && enabled_any libass libfreetype {lib,}fontconfig libfribidi; }; then
    do_pacman_remove freetype fontconfig harfbuzz fribidi

    _check=(libfreetype.a freetype2.pc)
    [[ $ffmpeg = sharedlibs ]] && _check+=(bin-video/libfreetype-6.dll libfreetype.dll.a)
    if do_vcs "$SOURCE_REPO_FREETYPE"; then
        do_uninstall include/freetype2 bin-global/freetype-config \
            bin{,-video}/libfreetype-6.dll libfreetype.dll.a "${_check[@]}"
        extracommands=(-D{harfbuzz,png,bzip2,brotli,zlib,tests}"=disabled")
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-library=both)
        do_mesoninstall global "${extracommands[@]}"
        [[ $ffmpeg = sharedlibs ]] && do_install "$LOCALDESTDIR"/bin/libfreetype-6.dll bin-video/
        do_checkIfExist
    fi

    _deps=(libfreetype.a)
    _check=(libfontconfig.{,l}a fontconfig.pc)
    [[ $ffmpeg = sharedlibs ]] && enabled_any {lib,}fontconfig &&
        do_removeOption "--enable-(lib|)fontconfig"
    if enabled_any {lib,}fontconfig &&
        do_vcs "$SOURCE_REPO_FONTCONFIG"; then
        do_uninstall include/fontconfig "${_check[@]}"
        sed -i 's| test$||' Makefile.am
        sed -i 's|Libs.private:|& -lintl|' fontconfig.pc.in
        for _s in printf fprintf snprintf vfprintf; do
            grep -Rl "$_s" --include="*.[c]" | xargs sed -i "/__mingw_/! s/\b$_s/__mingw_&/g"
        done
        unset _s
        do_autogen --noconf
        do_autoreconf
        extracommands=(--disable-docs --enable-iconv
            "--with-libiconv-prefix=$MINGW_PREFIX"
            "--with-libiconv-lib=$MINGW_PREFIX/lib" "--with-libiconv-includes=$MINGW_PREFIX/include"
            "LDFLAGS=$LDFLAGS -L${LOCALDESTDIR}/lib -L${MINGW_PREFIX}/lib")
        if enabled libxml2; then
            sed -i 's|Cflags:|& -DLIBXML_STATIC|' fontconfig.pc.in
            extracommands+=(--enable-libxml2)
        fi
        CFLAGS+=" $(enabled libxml2 && echo -DLIBXML_STATIC)" \
            do_separate_confmakeinstall global "${extracommands[@]}"
        [[ $standalone = y ]] || rm -f "$LOCALDESTDIR"/bin-global/fc-*.exe
        do_checkIfExist
    fi

    _deps=(libfreetype.a)
    _check=(libharfbuzz.a harfbuzz.pc)
    [[ $ffmpeg = sharedlibs ]] && _check+=(libharfbuzz.dll.a bin-video/libharfbuzz-{subset-,}0.dll)
    if do_vcs "$SOURCE_REPO_HARFBUZZ"; then
        do_pacman_install ragel icu
        do_uninstall include/harfbuzz "${_check[@]}" libharfbuzz{-subset,}.la
        extracommands=(-D{glib,gobject,cairo,icu,tests,introspection,docs,benchmark}"=disabled")
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-library=both)
        do_mesoninstall global "${extracommands[@]}"
        # directwrite shaper doesn't work with mingw headers, maybe too old
        [[ $ffmpeg = sharedlibs ]] && do_install "$LOCALDESTDIR"/bin-global/libharfbuzz-{subset-,}0.dll bin-video/
        do_checkIfExist
    fi

    _check=(libfribidi.a fribidi.pc)
    [[ $standalone = y ]] && _check+=(bin-video/fribidi.exe)
    [[ $ffmpeg = sharedlibs ]] && _check+=(bin-video/libfribidi-0.dll libfribidi.dll.a)
    if do_vcs "$SOURCE_REPO_FRIBIDI"; then
        extracommands=("-Ddocs=false" "-Dtests=false")
        [[ $standalone = n ]] && extracommands+=("-Dbin=false")
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--default-library=both)
        do_mesoninstall video "${extracommands[@]}"
        do_checkIfExist
    fi

    _check=(ass/ass{,_types}.h libass.{{,l}a,pc})
    _deps=(lib{freetype,fontconfig,harfbuzz,fribidi}.a)
    [[ $ffmpeg = sharedlibs ]] && _check+=(bin-video/libass-9.dll libass.dll.a)
    if do_vcs "$SOURCE_REPO_LIBASS"; then
        do_autoreconf
        do_uninstall bin{,-video}/libass-9.dll libass.dll.a include/ass "${_check[@]}"
        extracommands=()
        enabled_any {lib,}fontconfig || extracommands+=(--disable-fontconfig)
        [[ $ffmpeg = sharedlibs ]] && extracommands+=(--disable-fontconfig --enable-shared)
        do_separate_confmakeinstall video "${extracommands[@]}"
        do_checkIfExist
    fi
    if [[ $ffmpeg != sharedlibs && $ffmpeg != shared ]]; then
        _libs=(lib{freetype,harfbuzz{-subset,},fribidi,ass}.dll.a
            libav{codec,device,filter,format,util,resample}.dll.a
            lib{sw{scale,resample},postproc}.dll.a)
        for _lib in "${_libs[@]}"; do
            rm -f "$LOCALDESTDIR/lib/$_lib"
        done
        unset _lib _libs
    fi
fi

[[ $ffmpeg != no ]] && enabled gcrypt && do_pacman_install libgcrypt

if [[ $curl = y ]]; then
    enabled libtls && curl=libressl
    enabled openssl && curl=openssl
    enabled gnutls && curl=gnutls
    enabled mbedtls && curl=mbedtls
    [[ $curl = y ]] && curl=schannel
fi
_check=(libgnutls.{,l}a gnutls.pc)
_gnutls_ver=3.7.8
_gnutls_hash=c58ad39af0670efe6a8aee5e3a8b2331a1200418b64b7c51977fb396d4617114
if enabled_any gnutls librtmp || [[ $rtmpdump = y || $curl = gnutls ]] &&
    do_pkgConfig "gnutls = $_gnutls_ver" &&
    do_wget -h $_gnutls_hash \
    "https://www.gnupg.org/ftp/gcrypt/gnutls/v${_gnutls_ver%.*}/gnutls-${_gnutls_ver}.tar.xz"; then
        do_pacman_install nettle
        do_uninstall include/gnutls "${_check[@]}"
        grep_or_sed crypt32 lib/gnutls.pc.in 's/Libs.private.*/& -lcrypt32/'
        CFLAGS="-Wno-int-conversion" \
            do_separate_confmakeinstall \
            --disable-{cxx,doc,tools,tests,nls,rpath,libdane,guile,gcc-warnings} \
            --without-{p11-kit,idn,tpm} --enable-local-libopts \
            --with-included-unistring --disable-code-coverage \
            LDFLAGS="$LDFLAGS -L${LOCALDESTDIR}/lib -L${MINGW_PREFIX}/lib"
        do_checkIfExist
fi

if [[ $curl = openssl ]] || { [[ $ffmpeg != no ]] && enabled openssl; }; then
    do_pacman_install openssl
fi
hide_libressl -R
if [[ $curl = libressl ]] || { [[ $ffmpeg != no ]] && enabled libtls; }; then
    _check=(tls.h lib{crypto,ssl,tls}.{pc,{,l}a} openssl.pc)
    [[ $standalone = y ]] && _check+=(bin-global/openssl.exe)
    if do_vcs "$SOURCE_REPO_LIBRESSL" libressl; then
        do_uninstall etc/ssl include/openssl "${_check[@]}"
        _sed="man"
        [[ $standalone = y ]] || _sed="apps tests $_sed"
        sed -ri "s;(^SUBDIRS .*) $_sed;\1;" Makefile.am
        do_autogen
        do_separate_confmakeinstall global
        do_checkIfExist
        unset _sed
    fi
fi

{ enabled mbedtls || [[ $curl = mbedtls ]]; } && do_pacman_install mbedtls

if [[ $mediainfo = y || $bmx = y || $curl != n ]]; then
    do_pacman_install libunistring
    grep_and_sed dllimport "$MINGW_PREFIX"/include/unistring/woe32dll.h \
        's|__declspec \(dllimport\)||g' "$MINGW_PREFIX"/include/unistring/woe32dll.h
    _deps=("$MINGW_PREFIX/lib/libunistring.a")
    _check=(libidn2.{{,l}a,pc} idn2.h)
    [[ $standalone == y ]] && _check+=(bin-global/idn2.exe)
    if do_pkgConfig "libidn2 = 2.3.0" &&
        do_wget -h e1cb1db3d2e249a6a3eb6f0946777c2e892d5c5dc7bd91c74394fc3a01cab8b5 \
        "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.0.tar.gz"; then
        do_uninstall "${_check[@]}"
        [[ $standalone == y ]] || sed -ri 's|(bin_PROGRAMS = ).*|\1|g' src/Makefile.in
        # unistring also depends on iconv
        grep_or_sed '@LTLIBUNISTRING@ @LTLIBICONV@' libidn2.pc.in \
            's|(@LTLIBICONV@) (@LTLIBUNISTRING@)|\2 \1|'
        do_separate_confmakeinstall global --disable-{doc,rpath,nls}
        do_checkIfExist
    fi
    _deps=(libidn2.a)
    _check=(libpsl.{{,l}a,h,pc})
    [[ $standalone == y ]] && _check+=(bin-global/psl.exe)
    if do_pkgConfig "libpsl = 0.21.0" &&
        do_wget -h 41bd1c75a375b85c337b59783f5deb93dbb443fb0a52d257f403df7bd653ee12 \
        "https://github.com/rockdaboot/libpsl/releases/download/libpsl-0.21.0/libpsl-0.21.0.tar.gz"; then
        do_uninstall "${_check[@]}"
        [[ $standalone == y ]] || sed -ri 's|(bin_PROGRAMS = ).*|\1|g' tools/Makefile.in
        grep_or_sed "Requires.private" libpsl.pc.in "/Libs:/ i\Requires.private: libidn2"
        CFLAGS+=" -DPSL_STATIC" do_separate_confmakeinstall global --disable-{nls,rpath,gtk-doc-html,man,runtime}
        do_checkIfExist
    fi
fi

do_pacman_install brotli

_check=(curl/curl.h libcurl.{{,l}a,pc})
case $curl in
libressl) _deps=(libssl.a) ;;
openssl) _deps=("$MINGW_PREFIX/lib/libssl.a") ;;
gnutls) _deps=(libgnutls.a) ;;
mbedtls) _deps=("$MINGW_PREFIX/lib/libmbedtls.a") ;;
*) _deps=() ;;
esac
[[ $standalone = y || $curl != n ]] && _check+=(bin-global/curl.exe)
if [[ $mediainfo = y || $bmx = y || $curl != n || $cyanrip = y ]] &&
    do_vcs "https://github.com/curl/curl.git"; then
    do_patch "https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-curl/0003-libpsl-static-libs.patch"
    do_pacman_install nghttp2

    do_uninstall include/curl bin-global/curl-config "${_check[@]}"
    [[ $standalone = y || $curl != n ]] ||
        sed -ri "s;(^SUBDIRS = lib) src (include) scripts;\1 \2;" Makefile.in
    extra_opts=()
    case $curl in
    libressl|openssl)
        extra_opts+=(--with-{nghttp2,openssl} --without-{gnutls,mbedtls})
        ;;
    mbedtls) extra_opts+=(--with-{mbedtls,nghttp2} --without-openssl) ;;
    gnutls) extra_opts+=(--with-gnutls --without-{nghttp2,mbedtls,openssl}) ;;
    *) extra_opts+=(--with-{schannel,winidn,nghttp2} --without-{gnutls,mbedtls,openssl});;
    esac

    [[ ! -f configure || configure.ac -nt configure ]] &&
        do_autoreconf
    [[ $curl = openssl ]] && hide_libressl
    hide_conflicting_libs
    CPPFLAGS+=" -DGNUTLS_INTERNAL_BUILD -DNGHTTP2_STATICLIB -DPSL_STATIC" \
        do_separate_confmakeinstall global "${extra_opts[@]}" \
        --without-{libssh2,random,ca-bundle,ca-path,librtmp} \
        --with-brotli --enable-sspi --disable-debug
    hide_conflicting_libs -R
    [[ $curl = openssl ]] && hide_libressl -R
    if [[ $curl != schannel ]]; then
        _notrequired=true
        cd_safe "build-$bits"
        PATH=/usr/bin log ca-bundle make ca-bundle
        unset _notrequired
        [[ -f lib/ca-bundle.crt ]] &&
            cp -f lib/ca-bundle.crt "$LOCALDESTDIR"/bin-global/curl-ca-bundle.crt
        cd_safe ..
    fi
    do_checkIfExist
fi

if { { [[ $ffmpeg != no || $standalone = y ]] && enabled libtesseract; } ||
    { [[ $standalone = y ]] && enabled libwebp; }; }; then
    _check=(libglut.a glut.pc)
    if do_vcs "$SOURCE_REPO_LIBGLUT" freeglut; then
        do_uninstall lib/cmake/FreeGLUT include/GL "${_check[@]}"
        do_cmakeinstall -D{UNIX,FREEGLUT_BUILD_DEMOS,FREEGLUT_BUILD_SHARED_LIBS}=OFF -DFREEGLUT_REPLACE_GLUT=ON
        do_checkIfExist
    fi
    _deps=(libglut.a)
    _check=(libtiff{.a,-4.pc})
    if do_vcs "$SOURCE_REPO_LIBTIFF"; then
        do_patch "https://gitlab.com/libtiff/libtiff/-/merge_requests/233.patch" am
        do_pacman_install libjpeg-turbo xz zlib zstd libdeflate
        do_uninstall "${_check[@]}"
        grep_or_sed 'Requires.private' libtiff-4.pc.in \
            '/Libs:/ a\Requires.private: libjpeg liblzma zlib libzstd glut'
        CFLAGS+=" -DFREEGLUT_STATIC" do_cmakeinstall global -D{webp,jbig,UNIX,lerc}=OFF
        do_checkIfExist
    fi
fi

file_installed -s libtiff-4.pc &&
    grep_or_sed '-ldeflate' "$(file_installed libtiff-4.pc)" \
        's/Libs.private:.*/& -ldeflate/'

_check=(libwebp{,mux}.{a,pc})
[[ $standalone = y ]] && _check+=(libwebp{demux,decoder}.{a,pc}
    bin-global/{{c,d}webp,webpmux,img2webp}.exe)
if [[ $ffmpeg != no || $standalone = y ]] && enabled libwebp &&
    do_vcs "$SOURCE_REPO_LIBWEBP"; then
    do_pacman_install giflib
    do_uninstall include/webp bin-global/gif2webp.exe "${_check[@]}"
    extracommands=("-DWEBP_BUILD_EXTRAS=OFF" "-DWEBP_BUILD_VWEBP=OFF")
    if [[ $standalone = y ]]; then
        extracommands+=(-DWEBP_BUILD_{{C,D,GIF2,IMG2}WEBP,ANIM_UTILS,WEBPMUX}"=ON")
    else
        extracommands+=(-DWEBP_BUILD_{{C,D,GIF2,IMG2,V}WEBP,ANIM_UTILS,WEBPMUX}"=OFF")
    fi
    CFLAGS+=" -DFREEGLUT_STATIC" \
        do_cmakeinstall global -DWEBP_ENABLE_SWAP_16BIT_CSP=ON "${extracommands[@]}"
    do_checkIfExist
fi

if [[ $jpegxl = y ]] || { [[ $ffmpeg != no ]] && enabled libjxl; }; then
    _check=(libhwy{,_{contrib,test}}.a libhwy{,-{contrib,test}}.pc hwy/highway.h)
    if do_vcs "$SOURCE_REPO_LIBHWY"; then
        do_uninstall "${_check[@]}" include/hwy
        CXXFLAGS+=" -DHWY_COMPILE_ALL_ATTAINABLE" do_cmakeinstall
        do_checkIfExist
    fi

    _check=(bin/gflags_completions.sh gflags.pc gflags/gflags.h libgflags{,_nothreads}.a)
    if do_vcs "$SOURCE_REPO_GFLAGS"; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/gflags/0001-cmake-chop-off-.lib-extension-from-shlwapi.patch" am
        do_uninstall "${_check[@]}" lib/cmake/gflags include/gflags
        do_cmakeinstall -D{BUILD,INSTALL}_STATIC_LIBS=ON -DBUILD_gflags_LIB=ON -DINSTALL_HEADERS=ON \
            -DREGISTER_{BUILD_DIR,INSTALL_PREFIX}=OFF
        do_checkIfExist
    fi

    _deps=(libhwy.a libgflags.a)
    _check=(libjxl{{,_dec,_threads}.a,.pc} jxl/decode.h)
    [[ $jpegxl = y ]] && _check+=(bin-global/{{c,d}jxl,cjpeg_hdr,jxlinfo}.exe)
    if do_vcs "$SOURCE_REPO_LIBJXL"; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libjxl/0001-brotli-add-ldflags.patch" am
        do_uninstall "${_check[@]}" include/jxl
        do_pacman_install lcms2 asciidoc
        extracommands=()
        log -q "git.submodule" git submodule update --init --recursive
        [[ $jpegxl = y ]] || extracommands=("-DJPEGXL_ENABLE_TOOLS=OFF")
        do_cmakeinstall global -D{BUILD_TESTING,JPEGXL_ENABLE_{BENCHMARK,DOXYGEN,MANPAGES,OPENEXR,SKCMS,EXAMPLES}}=OFF \
            -DJPEGXL_{FORCE_SYSTEM_{BROTLI,HWY},STATIC}=ON -DJPEGXL_BUNDLE_GFLAGS=OFF "${extracommands[@]}"
        do_checkIfExist
        unset extracommands
    fi
fi

if files_exist bin-video/OpenCL.dll; then
    opencldll=$LOCALDESTDIR/bin-video/OpenCL.dll
else
    syspath=$(cygpath -S)
    [[ $bits = 32bit && -d $syspath/../SysWOW64 ]] && syspath+=/../SysWOW64
    opencldll=$syspath/OpenCL.dll
    unset syspath
fi
if [[ $ffmpeg != no && -f $opencldll ]] && enabled opencl; then
    do_simple_print "${orange}FFmpeg and related apps will depend on OpenCL.dll$reset"
    do_pacman_remove opencl-headers
    _check=(CL/cl.h)
    if do_vcs "$SOURCE_REPO_OPENCLHEADERS"; then
        do_uninstall include/CL
        do_install CL/*.h include/CL/
        do_checkIfExist
    fi
    _check=(libOpenCL.a)
    if test_newer installed "$opencldll" "${_check[@]}"; then
        cd_safe "$LOCALBUILDDIR"
        [[ -d opencl ]] && rm -rf opencl
        mkdir -p opencl && cd_safe opencl
        create_build_dir
        gendef "$opencldll" >/dev/null 2>&1
        [[ -f OpenCL.def ]] && dlltool -y libOpenCL.a -d OpenCL.def -k -A
        [[ -f libOpenCL.a ]] && do_install libOpenCL.a
        do_checkIfExist
    fi
else
    do_removeOption --enable-opencl
fi
unset opencldll

if [[ $ffmpeg != no || $standalone = y ]] && enabled libtesseract; then
    do_pacman_remove tesseract-ocr
    _check=(libleptonica.{,l}a lept.pc)
    if do_vcs "$SOURCE_REPO_LEPT"; then
        do_uninstall include/leptonica "${_check[@]}"
        [[ -f configure ]] || do_autogen
        do_separate_confmakeinstall --disable-programs --without-{lib{openjpeg,webp},giflib}
        do_checkIfExist
    fi

    _check=(libtesseract.{,l}a tesseract.pc)
    if do_vcs "$SOURCE_REPO_TESSERACT"; then
        do_pacman_install docbook-xsl libarchive pango asciidoc
        do_autogen
        _check+=(bin-global/tesseract.exe)
        do_uninstall include/tesseract "${_check[@]}"
        sed -i -e 's|Libs.private.*|& -lstdc++|' \
               -e 's|Requires.private.*|& libarchive iconv libtiff-4|' tesseract.pc.in
        grep_or_sed ws2_32 "$MINGW_PREFIX/lib/pkgconfig/libarchive.pc" 's;Libs.private:.*;& -lws2_32;g'
        case $CC in
        *gcc) sed -i -e 's|Libs.private.*|& -fopenmp -lgomp|' tesseract.pc.in ;;
        *clang) sed -i -e 's|Libs.private.*|& -fopenmp=libomp|' tesseract.pc.in ;;
        esac
        do_separate_confmakeinstall global --disable-{graphics,tessdata-prefix} \
            --without-curl \
            LIBLEPT_HEADERSDIR="$LOCALDESTDIR/include" \
            LIBS="$($PKG_CONFIG --libs iconv lept libtiff-4)" --datadir="$LOCALDESTDIR/bin-global"
        if [[ ! -f $LOCALDESTDIR/bin-global/tessdata/eng.traineddata ]]; then
            do_pacman_install tesseract-data-eng
            mkdir -p "$LOCALDESTDIR"/bin-global/tessdata
            do_install "$MINGW_PREFIX/share/tessdata/eng.traineddata" bin-global/tessdata/
            printf '%s\n' \
                "You can get more language data here:" \
                "https://github.com/tesseract-ocr/tessdata" \
                "Just download <lang you want>.traineddata and copy it to this directory." \
                > "$LOCALDESTDIR"/bin-global/tessdata/need_more_languages.txt
        fi
        do_checkIfExist
    fi
fi

_check=(librubberband.a rubberband.pc rubberband/{rubberband-c,RubberBandStretcher}.h)
if { { [[ $ffmpeg != no ]] && enabled librubberband; } ||
    ! mpv_disabled rubberband; } &&
    do_vcs "$SOURCE_REPO_RUBBERBAND"; then
    do_uninstall "${_check[@]}"
    log "distclean" make distclean
    do_make PREFIX="$LOCALDESTDIR" install-static
    do_checkIfExist
fi

_check=(zimg{.h,++.hpp} libzimg.{,l}a zimg.pc)
if [[ $ffmpeg != no ]] && enabled libzimg &&
    do_vcs "$SOURCE_REPO_ZIMG"; then
    log -q "git.submodule" git submodule update --init --recursive
    do_uninstall "${_check[@]}"
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/zimg/0001-libm_wrapper-define-__CRT__NO_INLINE-before-math.h.patch" am
    do_autoreconf
    do_separate_confmakeinstall
    do_checkIfExist
fi

set_title "compiling audio tools"
do_simple_print -p '\n\t'"${orange}Starting $bits compilation of audio tools${reset}"

if [[ $ffmpeg != no || $sox = y ]]; then
    do_pacman_install wavpack
    enabled_any libopencore-amr{wb,nb} && do_pacman_install opencore-amr
    if enabled libtwolame; then
        do_pacman_install twolame
        do_addOption --extra-cflags=-DLIBTWOLAME_STATIC
    fi
    enabled libmp3lame && do_pacman_install lame
fi

_check=(ilbc.h libilbc.{a,pc})
if [[ $ffmpeg != no ]] && enabled libilbc &&
    do_vcs "$SOURCE_REPO_LIBILBC"; then
    do_uninstall "${_check[@]}"
    log -q "git.submodule" git submodule update --init --recursive
    do_cmakeinstall -DUNIX=OFF
    do_checkIfExist
fi

grep_or_sed stdc++ "$(file_installed libilbc.pc)" "/Libs:/ a\Libs.private: -lstdc++"

enabled libvorbis && do_pacman_install libvorbis
enabled libspeex && do_pacman_install speex

_check=(bin-audio/speex{enc,dec}.exe)
if [[ $standalone = y ]] && enabled libspeex &&
    do_vcs "$SOURCE_REPO_SPEEX"; then
    do_uninstall include/speex libspeex.{l,}a speex.pc "${_check[@]}"
    do_autoreconf
    do_separate_conf --enable-vorbis-psy --enable-binaries
    do_make
    do_install src/speex{enc,dec}.exe bin-audio/
    do_checkIfExist
fi

_check=(libFLAC{,++}.{,l}a flac{,++}.pc)
[[ $standalone = y ]] && _check+=(bin-audio/flac.exe)
if [[ $flac = y ]] && do_vcs "$SOURCE_REPO_FLAC"; then
    do_pacman_install libogg
    do_autogen
    if [[ $standalone = y ]]; then
        _check+=(bin-audio/metaflac.exe)
    else
        sed -i "/^SUBDIRS/,/[^\\]$/{/flac/d;}" src/Makefile.in
    fi
    sed -i 's|__declspec(dllimport)||g' include/FLAC{,++}/export.h
    do_uninstall include/FLAC{,++} share/aclocal/libFLAC{,++}.m4 "${_check[@]}"
    do_separate_confmakeinstall audio --disable-{xmms-plugin,doxygen-docs}
    do_checkIfExist
elif [[ $sox = y ]] || { [[ $standalone = y ]] && enabled_any libvorbis libopus; }; then
    do_pacman_install flac
    grep_and_sed dllimport "$MINGW_PREFIX"/include/FLAC++/export.h \
        's|__declspec\(dllimport\)||g' "$MINGW_PREFIX"/include/FLAC{,++}/export.h
fi
grep_and_sed dllimport "$LOCALDESTDIR"/include/FLAC++/export.h \
        's|__declspec\(dllimport\)||g' "$LOCALDESTDIR"/include/FLAC{,++}/export.h

_check=(libvo-amrwbenc.{l,}a vo-amrwbenc.pc)
if [[ $ffmpeg != no ]] && enabled libvo-amrwbenc &&
    do_pkgConfig "vo-amrwbenc = 0.1.3" &&
    do_wget_sf -h f63bb92bde0b1583cb3cb344c12922e0 \
        "opencore-amr/vo-amrwbenc/vo-amrwbenc-0.1.3.tar.gz"; then
    do_uninstall include/vo-amrwbenc "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi

if { [[ $ffmpeg != no ]] && enabled libfdk-aac; } || [[ $fdkaac = y ]]; then
    _check=(libfdk-aac.{l,}a fdk-aac.pc)
    if do_vcs "$SOURCE_REPO_FDKAAC"; then
        do_autoreconf
        do_uninstall include/fdk-aac "${_check[@]}"
        CXXFLAGS+=" -fno-exceptions -fno-rtti" do_separate_confmakeinstall
        do_checkIfExist
    fi
    _check=(bin-audio/fdkaac.exe)
    _deps=(libfdk-aac.a)
    if [[ $standalone = y ]] &&
        do_vcs "$SOURCE_REPO_FDKAACEXE" bin-fdk-aac; then
        do_autoreconf
        do_uninstall "${_check[@]}"
        do_separate_confmakeinstall audio
        do_checkIfExist
    fi
fi

[[ $faac = y ]] && do_pacman_install faac
_check=(bin-audio/faac.exe)
if [[ $standalone = y && $faac = y ]] &&
    do_vcs "$SOURCE_REPO_FAAC"; then
    do_uninstall libfaac.a faac{,cfg}.h "${_check[@]}"
    log bootstrap ./bootstrap
    do_separate_confmakeinstall audio
    do_checkIfExist
fi

_check=(bin-audio/exhale.exe)
if [[ $exhale = y ]] &&
    do_vcs "$SOURCE_REPO_EXHALE"; then
    do_uninstall "${_check[@]}"
    _notrequired=true
    do_cmakeinstall audio
    do_checkIfExist
    unset _notrequired
fi

_check=(bin-audio/oggenc.exe)
_deps=("$MINGW_PREFIX"/lib/libvorbis.a)
if [[ $standalone = y ]] && enabled libvorbis &&
    do_vcs "$SOURCE_REPO_LIBVORBIS"; then
    do_patch "https://github.com/xiph/vorbis-tools/pull/39.patch" am
    _check+=(bin-audio/oggdec.exe)
    do_autoreconf
    do_uninstall "${_check[@]}"
    extracommands=()
    enabled libspeex || extracommands+=(--without-speex)
    do_separate_conf --disable-{ogg123,vorbiscomment,vcut,ogginfo} \
        --with-lib{iconv,intl}-prefix="$MINGW_PREFIX" "${extracommands[@]}"
    do_make
    do_install oggenc/oggenc.exe oggdec/oggdec.exe bin-audio/
    do_checkIfExist
fi

_check=(libopus.{,l}a opus.pc opus/opus.h)
if enabled libopus && do_vcs "$SOURCE_REPO_OPUS"; then
    do_pacman_remove opus
    do_uninstall include/opus "${_check[@]}"
    do_autogen
    do_separate_confmakeinstall --disable-{stack-protector,doc,extra-programs}
    do_checkIfExist
fi

if [[ $standalone = y ]] && enabled libopus; then
    do_pacman_install openssl libogg
    hide_libressl
    _check=(opus/opusfile.h libopus{file,url}.{,l}a opus{file,url}.pc)
    _deps=(opus.pc "$MINGW_PREFIX"/lib/pkgconfig/{libssl,ogg}.pc)
    if do_vcs "$SOURCE_REPO_OPUSFILE"; then
        do_uninstall "${_check[@]}"
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/opusfile/0001-Disable-cert-store-integration-if-OPENSSL_VERSION_NU.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/opusfile/0002-configure-Only-add-std-c89-if-not-mingw-because-of-c.patch" am
        do_autogen
        do_separate_confmakeinstall --disable-{examples,doc}
        do_checkIfExist
    fi

    _check=(opus/opusenc.h libopusenc.{pc,{,l}a})
    _deps=(opus.pc)
    if do_vcs "$SOURCE_REPO_LIBOPUSENC"; then
        do_uninstall "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall --disable-{examples,doc}
        do_checkIfExist
    fi

    _check=(bin-audio/opusenc.exe)
    _deps=(opusfile.pc libopusenc.pc)
    if do_vcs "$SOURCE_REPO_OPUSEXE"; then
        _check+=(bin-audio/opus{dec,info}.exe)
        do_uninstall "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall audio
        do_checkIfExist
    fi
    hide_libressl -R
fi

_check=(soxr.h libsoxr.a)
if [[ $ffmpeg != no ]] && enabled libsoxr &&
    do_vcs "$SOURCE_REPO_LIBSOXR"; then
    do_uninstall "${_check[@]}"
    do_cmakeinstall -D{WITH_LSR_BINDINGS,BUILD_TESTS,WITH_OPENMP}=off
    do_checkIfExist
fi

_check=(libcodec2.a codec2.pc codec2/codec2.h)
if [[ $ffmpeg != no ]] && enabled libcodec2; then
    if do_vcs "$SOURCE_REPO_CODEC2"; then
        do_uninstall all include/codec2 "${_check[@]}"
        sed -i 's|if(WIN32)|if(FALSE)|g' CMakeLists.txt
        if enabled libspeex; then
            # rename same-named symbols copied from speex
            grep -ERl "\b(lsp|lpc)_to_(lpc|lsp)" --include="*.[ch]" | \
                xargs -r sed -ri "s;((lsp|lpc)_to_(lpc|lsp));c2_\1;g"
        fi
        do_cmakeinstall -D{UNITTEST,INSTALL_EXAMPLES}=off \
            -DCMAKE_INSTALL_BINDIR="$(pwd)/build-$bits/_bin"
        do_checkIfExist
    fi
fi

if [[ $standalone = y ]] && enabled libmp3lame; then
    _check=(bin-audio/lame.exe)
    if files_exist "${_check[@]}" &&
        grep -q "3.100" "$LOCALDESTDIR/bin-audio/lame.exe"; then
        do_print_status "lame 3.100" "$green" "Up-to-date"
    elif do_wget_sf \
            -h ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e \
            "lame/lame/3.100/lame-3.100.tar.gz"; then
        do_uninstall include/lame libmp3lame.{l,}a "${_check[@]}"
        _mingw_patches_lame="https://raw.githubusercontent.com/Alexpux/MINGW-packages/master/mingw-w64-lame"
        do_patch "$_mingw_patches_lame/0005-no-gtk.all.patch"
        do_patch "$_mingw_patches_lame/0006-dont-use-outdated-symbol-list.patch"
        do_patch "$_mingw_patches_lame/0007-revert-posix-code.patch"
        do_patch "$_mingw_patches_lame/0008-skip-termcap.patch"
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/lame/0001-libmp3lame-vector-Makefile.am-Add-msse-to-fix-i686-c.patch"
        do_autoreconf
        do_separate_conf --enable-nasm
        do_make
        do_install frontend/lame.exe bin-audio/
        do_checkIfExist
        unset _mingw_patches_lame
    fi
fi

_check=(libgme.{a,pc})
if [[ $ffmpeg != no ]] && enabled libgme && do_pkgConfig "libgme = 0.6.3" &&
    do_wget -h aba34e53ef0ec6a34b58b84e28bf8cfbccee6585cebca25333604c35db3e051d \
        "https://bitbucket.org/mpyne/game-music-emu/downloads/game-music-emu-0.6.3.tar.xz"; then
    do_uninstall include/gme "${_check[@]}"
    do_cmakeinstall -DENABLE_UBSAN=OFF
    do_checkIfExist
fi

_check=(libbs2b.{{l,}a,pc})
if [[ $ffmpeg != no ]] && enabled libbs2b && do_pkgConfig "libbs2b = 3.1.0" &&
    do_wget_sf -h c1486531d9e23cf34a1892ec8d8bfc06 "bs2b/libbs2b/3.1.0/libbs2b-3.1.0.tar.bz2"; then
    do_uninstall include/bs2b "${_check[@]}"
    # sndfile check is disabled since we don't compile binaries anyway
    /usr/bin/grep -q sndfile configure && sed -i '20119,20133d' configure
    sed -i "s|bin_PROGRAMS = .*||" src/Makefile.in
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(libsndfile.a sndfile.{h,pc})
if [[ $sox = y ]] && do_vcs "$SOURCE_REPO_SNDFILE" sndfile; then
    do_uninstall include/sndfile.hh "${_check[@]}"
    do_cmakeinstall -DBUILD_EXAMPLES=off -DBUILD_TESTING=off -DBUILD_PROGRAMS=OFF
    do_checkIfExist
fi

_check=(bin-audio/sox.exe sox.pc)
_deps=(libsndfile.a opus.pc "$MINGW_PREFIX"/lib/libmp3lame.a)
if [[ $sox = y ]] && do_pkgConfig "sox = 14.4.2" &&
    do_wget_sf -h ba804bb1ce5c71dd484a102a5b27d0dd "sox/sox/14.4.2/sox-14.4.2.tar.bz2"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/sox/0001-sox_version-fold-function-into-sox_version_info.patch"
    do_pacman_install libmad
    do_uninstall sox.{pc,h} bin-audio/{soxi,play,rec}.exe libsox.{l,}a "${_check[@]}"
    extracommands=()
    enabled libmp3lame || extracommands+=(--without-lame)
    enabled_any libopencore-amr{wb,nb} || extracommands+=(--without-amr{wb,nb})
    if enabled libopus; then
        do_pacman_install opusfile
    else
        extracommands+=(--without-opus)
    fi
    if enabled libtwolame; then
        extracommands+=(CFLAGS="$CFLAGS -DLIBTWOLAME_STATIC")
    else
        extracommands+=(--without-twolame)
    fi
    enabled libvorbis || extracommands+=(--without-oggvorbis)
    hide_conflicting_libs
    sed -i 's|found_libgsm=yes|found_libgsm=no|g' configure
    do_separate_conf --disable-symlinks LIBS='-lshlwapi -lz' "${extracommands[@]}"
    do_make
    do_install src/sox.exe bin-audio/
    do_install sox.pc
    hide_conflicting_libs -R
    do_checkIfExist
fi
unset _deps

_check=(libopenmpt.{a,pc})
if [[ $ffmpeg != no ]] && enabled libopenmpt &&
    do_vcs "$SOURCE_REPO_LIBOPENMPT"; then
    do_uninstall include/libopenmpt "${_check[@]}"
    mkdir bin 2> /dev/null
    extracommands=("CONFIG=mingw64-win${bits%bit}" "AR=ar" "STATIC_LIB=1" "EXAMPLES=0" "OPENMPT123=0"
        "TEST=0" "OS=" "CC=$CC" "CXX=$CXX" "MINGW_COMPILER=${CC##* }")
    log clean make clean "${extracommands[@]}"
    do_makeinstall PREFIX="$LOCALDESTDIR" "${extracommands[@]}"
    sed -i 's/Libs.private.*/& -lrpcrt4 -lstdc++/' "$LOCALDESTDIR/lib/pkgconfig/libopenmpt.pc"
    do_checkIfExist
fi

_check=(libmysofa.{a,pc} mysofa.h)
if [[ $ffmpeg != no ]] && enabled libmysofa &&
    do_vcs "$SOURCE_REPO_LIBMYSOFA"; then
    do_uninstall "${_check[@]}"
    do_cmakeinstall -DBUILD_TESTS=no -DCODE_COVERAGE=OFF
    do_checkIfExist
fi

_check=(libflite.a flite/flite.h)
if enabled libflite && do_vcs "$SOURCE_REPO_FLITE"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/flite/0001-tools-find_sts_main.c-Include-windows.h-before-defin.patch" am
    do_uninstall libflite_cmu_{grapheme,indic}_{lang,lex}.a \
        libflite_cmu_us_{awb,kal,kal16,rms,slt}.a \
        libflite_{cmulex,usenglish,cmu_time_awb}.a "${_check[@]}" include/flite
    log clean make clean
    do_configure --bindir="$LOCALDESTDIR"/bin-audio --disable-shared \
        --with-audio=none
    do_make && do_makeinstall
    do_checkIfExist
fi

_check=(shine/layer3.h libshine.{,l}a shine.pc)
[[ $standalone = y ]] && _check+=(bin-audio/shineenc.exe)
if enabled libshine && do_pkgConfig "shine = 3.1.1" &&
    do_wget -h 58e61e70128cf73f88635db495bfc17f0dde3ce9c9ac070d505a0cd75b93d384 \
        "https://github.com/toots/shine/releases/download/3.1.1/shine-3.1.1.tar.gz"; then
    do_uninstall "${_check[@]}"
    [[ $standalone = n ]] && sed -i '/bin_PROGRAMS/,+4d' Makefile.am
    # fix out-of-root build
    # shellcheck disable=SC2016
    sed -ri -e 's;(libshine.sym)$;$(srcdir)/\1;' \
        -e '/libshine_la_HEADERS/{s;(src/lib);$(srcdir)/\1;}' \
        -e '/shineenc_CFLAGS/{s;(src/lib);$(srcdir)/\1;}' Makefile.am
    rm configure
    do_autoreconf
    do_separate_confmakeinstall audio
    do_checkIfExist
fi

_check=(openal.pc libopenal.a)
if { { [[ $ffmpeg != no ]] &&
    enabled openal; } || mpv_enabled openal; } &&
    do_vcs "$SOURCE_REPO_OPENAL"; then
    do_uninstall "${_check[@]}"
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/openal-soft/0001-CMake-Fix-issues-for-mingw-w64.patch" am
    do_cmakeinstall -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF
    sed -i 's/Libs.private.*/& -lole32 -lstdc++/' "$LOCALDESTDIR/lib/pkgconfig/openal.pc"
    do_checkIfExist
    unset _mingw_patches
fi

set_title "compiling video tools"
do_simple_print -p '\n\t'"${orange}Starting $bits compilation of video tools${reset}"

_deps=(gnutls.pc)
_check=(librtmp.{a,pc})
[[ $rtmpdump = y || $standalone = y ]] && _check+=(bin-video/rtmpdump.exe)
if { [[ $rtmpdump = y ]] ||
    { [[ $ffmpeg != no ]] && enabled librtmp; }; } &&
    do_vcs "$SOURCE_REPO_LIBRTMP" librtmp; then
    [[ $rtmpdump = y || $standalone = y ]] && _check+=(bin-video/rtmp{suck,srv,gw}.exe)
    do_uninstall include/librtmp "${_check[@]}"
    [[ -f librtmp/librtmp.a ]] && log "clean" make clean
    _rtmp_pkgver() {
        printf '%s-%s-%s_%s-%s-static' \
            "$(/usr/bin/grep -oP "(?<=^VERSION=).+" Makefile)" \
            "$(git log -1 --format=format:%cd-g%h --date=format:%Y%m%d)" \
            "GnuTLS" \
            "$($PKG_CONFIG --modversion gnutls)" \
            "$CARCH"
    }
    do_makeinstall XCFLAGS="$CFLAGS -I$MINGW_PREFIX/include" XLDFLAGS="$LDFLAGS" SHARED= \
        SYS=mingw prefix="$LOCALDESTDIR" bindir="$LOCALDESTDIR"/bin-video \
        sbindir="$LOCALDESTDIR"/bin-video mandir="$LOCALDESTDIR"/share/man \
        CRYPTO=GNUTLS LIB_GNUTLS="$($PKG_CONFIG --libs gnutls) -lz" \
        VERSION="$(_rtmp_pkgver)"
    do_checkIfExist
    unset _rtmp_pkgver
fi

_check=(libvpx.a vpx.pc)
[[ $standalone = y ]] && _check+=(bin-video/vpxenc.exe)
if { enabled libvpx || [[ $vpx = y ]]; } && do_vcs "$SOURCE_REPO_VPX" vpx; then
    extracommands=()
    [[ -f config.mk ]] && log "distclean" make distclean
    [[ $standalone = y ]] && _check+=(bin-video/vpxdec.exe) ||
        extracommands+=(--disable-{examples,webm-io,libyuv,postproc})
    do_uninstall include/vpx "${_check[@]}"
    create_build_dir
    [[ $bits = 32bit ]] && arch=x86 || arch=x86_64
    [[ $ffmpeg = sharedlibs ]] || extracommands+=(--enable-{vp9-postproc,vp9-highbitdepth})
    get_external_opts extracommands
    config_path=.. do_configure --target="${arch}-win${bits%bit}-gcc" \
        --disable-{shared,unit-tests,docs,install-bins} \
        "${extracommands[@]}"
    sed -i 's;HAVE_GNU_STRIP=yes;HAVE_GNU_STRIP=no;' -- ./*.mk
    do_make
    do_makeinstall
    [[ $standalone = y ]] && do_install vpx{enc,dec}.exe bin-video/
    do_checkIfExist
    unset extracommands
else
    pc_exists vpx || do_removeOption --enable-libvpx
fi

_check=(libvmaf.{a,pc} libvmaf/libvmaf.h)
if [[ $ffmpeg != no ]] && enabled libvmaf &&
    do_vcs "$SOURCE_REPO_LIBVMAF"; then
    do_uninstall share/model "${_check[@]}"
    do_pacman_install -m vim # for built_in_models
    cd_safe libvmaf
    CFLAGS="-msse2 -mfpmath=sse -mstackrealign $CFLAGS" do_mesoninstall video \
        -Denable_float=true -Dbuilt_in_models=true
    do_checkIfExist
fi
file_installed -s libvmaf.dll.a && rm "$(file_installed libvmaf.dll.a)"
grep_or_sed stdc++ "$(file_installed libvmaf.pc)" 's;Libs.private.*;& -lstdc++;'

_check=(libaom.a aom.pc)
if [[ $aom = y || $standalone = y ]]; then
    _aom_bins=true
    _check+=(bin-video/aomenc.exe)
else
    _aom_bins=false
fi
if { [[ $aom = y ]] || [[ $libavif = y ]] || { [[ $ffmpeg != no ]] && enabled libaom; }; } &&
    do_vcs "$SOURCE_REPO_LIBAOM"; then
    extracommands=()
    if $_aom_bins; then
        _check+=(bin-video/aomdec.exe)
        # fix google's shit
        sed -ri 's;_PREFIX.+CMAKE_INSTALL_BINDIR;_FULL_BINDIR;' \
            build/cmake/aom_install.cmake
    else
        extracommands+=("-DENABLE_EXAMPLES=off")
    fi
    do_uninstall include/aom "${_check[@]}"
    get_external_opts extracommands
    do_cmakeinstall video -DENABLE_{DOCS,TOOLS,TEST{S,DATA}}=off \
        -DENABLE_NASM=on -DFORCE_HIGHBITDEPTH_DECODING=0 "${extracommands[@]}"
    do_checkIfExist
    unset extracommands
fi
unset _aom_bins

_check=(dav1d/dav1d.h dav1d.pc libdav1d.a)
[[ $standalone = y ]] && _check+=(bin-video/dav1d.exe)
if { [[ $dav1d = y ]] || [[ $libavif = y ]] || { [[ $ffmpeg != no ]] && enabled libdav1d; }; } &&
    do_vcs "$SOURCE_REPO_DAV1D"; then
    do_uninstall include/dav1d "${_check[@]}"
    extracommands=()
    [[ $standalone = y ]] || extracommands=("-Denable_tools=false")
    do_mesoninstall video -Denable_{tests,examples}=false "${extracommands[@]}"
    do_checkIfExist
fi

_check=(/opt/cargo/bin/cargo-c{build,api}.exe)
if { enabled librav1e || [[ $libavif = y ]]; } &&
    do_vcs "$SOURCE_REPO_CARGOC"; then
    # Delete any old cargo-cbuilds
    [[ -x /opt/cargo/bin/cargo-cbuild.exe ]] && log uninstall.cargo-c cargo uninstall -q cargo-c
    do_rustinstall
    do_checkIfExist
fi

_check=()
{ [[ $rav1e = y ]] ||
    enabled librav1e && [[ $standalone = y ]]; } &&
    _check+=(bin-video/rav1e.exe)
{ enabled librav1e || [[ $libavif = y ]]; } && _check+=(librav1e.a rav1e.pc rav1e/rav1e.h)
if { [[ $rav1e = y ]] || [[ $libavif = y ]] || enabled librav1e; } &&
    do_vcs "$SOURCE_REPO_LIBRAV1E"; then
    do_uninstall "${_check[@]}" include/rav1e

    # standalone binary
    if [[ $rav1e = y || $standalone = y ]]; then
        do_rust --profile release-no-lto
        find "target/$CARCH-pc-windows-gnu" -name "rav1e.exe" | while read -r f; do
            do_install "$f" bin-video/
        done
    fi

    # C lib
    if [[ $libavif = y ]] || enabled librav1e; then
        rm -f "$CARGO_HOME/config" 2> /dev/null
        PKG_CONFIG="$LOCALDESTDIR/bin/ab-pkg-config-static.bat" \
            CC="ccache clang" \
            CXX="ccache clang++" \
            log "install-rav1e-c" "$RUSTUP_HOME/bin/cargo.exe" capi install \
            --release --jobs "$cpuCount" --prefix="$LOCALDESTDIR" \
            --destdir="$PWD/install-$bits"

        # do_install "install-$bits/bin/rav1e.dll" bin-video/
        # do_install "install-$bits/lib/librav1e.dll.a" lib/
        do_install "$(find "install-$bits/" -name "librav1e.a")" lib/
        do_install "$(find "install-$bits/" -name "rav1e.pc")" lib/pkgconfig/
        sed -i 's/\\/\//g' "$LOCALDESTDIR/lib/pkgconfig/rav1e.pc" >/dev/null 2>&1
        do_install "$(find "install-$bits/" -name "rav1e")"/*.h include/rav1e/
    fi

    do_checkIfExist
fi

_check=(libavif.{a,pc} avif/avif.h)
[[ $standalone = y ]] && _check+=(bin-video/avif{enc,dec}.exe)
if [[ $libavif = y ]] && {
        pc_exists "aom" || pc_exists "dav1d" || pc_exists "rav1e"
    } &&
    do_vcs "$SOURCE_REPO_LIBAVIF"; then
    do_uninstall "${_check[@]}"
    do_pacman_install libjpeg-turbo
    extracommands=()
    pc_exists "dav1d" && extracommands+=("-DAVIF_CODEC_DAV1D=ON")
    pc_exists "rav1e" && extracommands+=("-DAVIF_CODEC_RAV1E=ON")
    pc_exists "aom" && extracommands+=("-DAVIF_CODEC_AOM=ON")
    case $standalone in
    y) extracommands+=("-DAVIF_BUILD_APPS=ON") ;;
    *) extracommands+=("-DAVIF_BUILD_APPS=OFF") ;;
    esac
    do_cmakeinstall video -DAVIF_ENABLE_WERROR=OFF "${extracommands[@]}"
    do_checkIfExist
fi

_check=(libkvazaar.{,l}a kvazaar.pc kvazaar.h)
[[ $standalone = y ]] && _check+=(bin-video/kvazaar.exe)
if { [[ $other265 = y ]] || { [[ $ffmpeg != no ]] && enabled libkvazaar; }; } &&
    do_vcs "$SOURCE_REPO_LIBKVAZAAR"; then
    do_patch "https://github.com/m-ab-s/mabs-patches/raw/master/kvazaar/0001-Mingw-w64-Re-enable-avx2.patch" am
    do_uninstall kvazaar_version.h "${_check[@]}"
    do_autogen
    [[ $standalone = y || $other265 = y ]] ||
        sed -i "s|bin_PROGRAMS = .*||" src/Makefile.in
    CFLAGS+=" -fno-asynchronous-unwind-tables -DKVZ_BIT_DEPTH=10" \
        do_separate_confmakeinstall video
    do_checkIfExist
fi

_check=(libSDL2{,_test,main}.a sdl2.pc SDL2/SDL.h)
if { { [[ $ffmpeg != no ]] &&
    { enabled sdl2 || ! disabled_any sdl2 autodetect; }; } ||
    mpv_enabled sdl2; } &&
    do_vcs "$SOURCE_REPO_SDL2"; then
    do_uninstall include/SDL2 lib/cmake/SDL2 bin/sdl2-config "${_check[@]}"
    do_autogen
    sed -i 's|__declspec(dllexport)||g' include/{begin_code,SDL_opengl}.h
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(libdvdread.{l,}a dvdread.pc)
if { [[ $mplayer = y ]] || mpv_enabled dvdnav; } &&
    do_vcs "$SOURCE_REPO_LIBDVDREAD" dvdread; then
    do_autoreconf
    do_uninstall include/dvdread "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi
[[ -f $LOCALDESTDIR/lib/pkgconfig/dvdread.pc ]] &&
    grep_or_sed "Libs.private" "$LOCALDESTDIR"/lib/pkgconfig/dvdread.pc \
        "/Libs:/ a\Libs.private: -ldl -lpsapi"

_check=(libdvdnav.{l,}a dvdnav.pc)
_deps=(libdvdread.a)
if { [[ $mplayer = y ]] || mpv_enabled dvdnav; } &&
    do_vcs "$SOURCE_REPO_LIBDVDNAV" dvdnav; then
    do_autoreconf
    do_uninstall include/dvdnav "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi
unset _deps

if { [[ $ffmpeg != no ]] && enabled_any gcrypt libbluray; } ||
    ! mpv_disabled libbluray; then
    do_pacman_install libgcrypt
    grep_or_sed ws2_32 "$MINGW_PREFIX/bin/libgcrypt-config" 's;-lgpg-error;& -lws2_32;'
    grep_or_sed ws2_32 "$MINGW_PREFIX/bin/gpg-error-config" 's;-lgpg-error;& -lws2_32;'
fi


if { [[ $ffmpeg != no ]] && enabled libbluray; } || ! mpv_disabled libbluray; then
    _check=(bin-video/libaacs.dll libaacs.{{,l}a,pc} libaacs/aacs.h)
    if do_vcs "$SOURCE_REPO_LIBAACS"; then
        sed -ri 's;bin_PROGRAMS.*;bin_PROGRAMS = ;' Makefile.am
        do_autoreconf
        do_uninstall "${_check[@]}" include/libaacs
        do_separate_confmakeinstall video --enable-shared --with-libgcrypt-prefix="$MINGW_PREFIX"
        mv -f "$LOCALDESTDIR/bin/libaacs-0.dll" "$LOCALDESTDIR/bin-video/libaacs.dll"
        rm -f "$LOCALDESTDIR/bin-video/${MINGW_CHOST}-aacs_info.exe"
        do_checkIfExist
    fi

    _check=(bin-video/libbdplus.dll libbdplus.{{,l}a,pc} libbdplus/bdplus.h)
    if do_vcs "$SOURCE_REPO_LIBBDPLUS"; then
        sed -ri 's;noinst_PROGRAMS.*;noinst_PROGRAMS = ;' Makefile.am
        do_autoreconf
        do_uninstall "${_check[@]}" include/libbdplus
        do_separate_confmakeinstall video --enable-shared
        mv -f "$LOCALDESTDIR/bin/libbdplus-0.dll" "$LOCALDESTDIR/bin-video/libbdplus.dll"
        do_checkIfExist
    fi
fi

_check=(libbluray.{{l,}a,pc})
if { { [[ $ffmpeg != no ]] && enabled libbluray; } || ! mpv_disabled libbluray; } &&
    do_vcs "$SOURCE_REPO_LIBBLURAY"; then
    [[ -f contrib/libudfread/.git ]] || log git.submodule git submodule update --init
    do_autoreconf
    do_uninstall include/libbluray share/java "${_check[@]}"
    sed -i 's|__declspec(dllexport)||g' jni/win32/jni_md.h
    extracommands=()
    log javahome get_java_home
    OLD_PATH=$PATH
    if [[ -n $JAVA_HOME ]]; then
        if [[ ! -f /opt/apache-ant/bin/ant ]] ; then
            apache_ant_ver=$(clean_html_index "https://www.apache.org/dist/ant/binaries/")
            apache_ant_ver=$(get_last_version "$apache_ant_ver" "apache-ant" "1\.\d+\.\d+")
            if do_wget -r -c \
                "https://www.apache.org/dist/ant/binaries/apache-ant-${apache_ant_ver:-1.10.6}-bin.zip" \
                apache-ant.zip; then
                rm -rf /opt/apache-ant
                mv apache-ant /opt/apache-ant
            fi
        fi
        PATH=/opt/apache-ant/bin:$JAVA_HOME/bin:$PATH
        log ant-diagnostics ant -diagnostics
        export JDK_HOME=''
        export JAVA_HOME
    else
        extracommands+=(--disable-bdjava-jar)
    fi
    if enabled libxml2; then
        sed -ri 's;(Cflags.*);\1 -DLIBXML_STATIC;' src/libbluray.pc.in
    else
        extracommands+=(--without-libxml2)
    fi
    CFLAGS+=" $(enabled libxml2 && echo "-DLIBXML_STATIC")" \
        do_separate_confmakeinstall --disable-{examples,doxygen-doc} \
        --without-{fontconfig,freetype} "${extracommands[@]}"
    do_checkIfExist
    PATH=$OLD_PATH
    unset extracommands JDK_HOME JAVA_HOME OLD_PATH
fi

_check=(libxavs.a xavs.{h,pc})
if [[ $ffmpeg != no ]] && enabled libxavs && do_pkgConfig "xavs = 0.1." "0.1" &&
    do_vcs "$SOURCE_REPO_XAVS"; then
    do_patch "https://github.com/Distrotech/xavs/pull/1.patch"
    [[ -f libxavs.a ]] && log "distclean" make distclean
    do_uninstall "${_check[@]}"
    sed -i 's|"NUL"|"/dev/null"|g' configure
    do_configure
    do_make libxavs.a
    for _file in xavs.h libxavs.a xavs.pc; do do_install "$_file"; done
    do_checkIfExist
    unset _file
fi

_check=(libxavs2.a xavs2_config.h xavs2.{h,pc})
[[ $standalone = y ]] && _check+=(bin-video/xavs2.exe)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libxavs2
elif { [[ $avs2 = y ]] || { [[ $ffmpeg != no ]] && enabled libxavs2; }; } &&
    do_vcs "$SOURCE_REPO_XAVS2"; then
    cd_safe build/linux
    [[ -f config.mak ]] && log "distclean" make distclean
    do_uninstall all "${_check[@]}"
    do_configure --bindir="$LOCALDESTDIR"/bin-video --enable-static --enable-strip
    do_makeinstall
    do_checkIfExist
fi

_check=(libdavs2.a davs2_config.h davs2.{h,pc})
[[ $standalone = y ]] && _check+=(bin-video/davs2.exe)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libdavs2
elif { [[ $avs2 = y ]] || { [[ $ffmpeg != no ]] && enabled libdavs2; }; } &&
    do_vcs "$SOURCE_REPO_DAVS"; then
    cd_safe build/linux
    [[ -f config.mak ]] && log "distclean" make distclean
    do_uninstall all "${_check[@]}"
    do_configure --bindir="$LOCALDESTDIR"/bin-video --enable-strip
    do_makeinstall
    do_checkIfExist
fi

_check=(libuavs3d.a uavs3d.{h,pc})
[[ $standalone = y ]] && _check+=(bin-video/uavs3dec.exe)
if [[ $ffmpeg != no ]] && enabled libuavs3d &&
    do_vcs "$SOURCE_REPO_UAVS3D"; then
    do_patch "https://github.com/uavs3/uavs3d/pull/29.patch"
    do_cmakeinstall
    [[ $standalone = y ]] && do_install uavs3dec.exe bin-video/
    do_checkIfExist
fi

if [[ $mediainfo = y ]]; then
    [[ $curl = openssl ]] && hide_libressl
    _check=(libzen.{a,pc})
    if do_vcs "$SOURCE_REPO_LIBZEN" libzen; then
        do_uninstall include/ZenLib bin-global/libzen-config \
            "${_check[@]}" libzen.la lib/cmake/zenlib
        do_cmakeinstall Project/CMake
        do_checkIfExist
    fi
    fix_cmake_crap_exports "$LOCALDESTDIR/lib/cmake/zenlib"

    _check=(libmediainfo.{a,pc})
    _deps=(lib{zen,curl}.a)
    if do_vcs "$SOURCE_REPO_LIBMEDIAINFO" libmediainfo; then
        do_uninstall include/MediaInfo{,DLL} bin-global/libmediainfo-config \
            "${_check[@]}" libmediainfo.la lib/cmake/mediainfolib
        do_cmakeinstall Project/CMake -DBUILD_ZLIB=off -DBUILD_ZENLIB=off
        do_checkIfExist
    fi
    fix_cmake_crap_exports "$LOCALDESTDIR/lib/cmake/mediainfolib"

    _check=(bin-video/mediainfo.exe)
    _deps=(libmediainfo.a)
    if do_vcs "$SOURCE_REPO_MEDIAINFO" mediainfo; then
        cd_safe Project/GNU/CLI
        do_autogen
        do_uninstall "${_check[@]}"
        [[ -f Makefile ]] && log distclean make distclean
        do_configure --disable-shared --bindir="$LOCALDESTDIR/bin-video" \
            --enable-staticlibs
        do_makeinstall
        do_checkIfExist
    fi
    [[ $curl = openssl ]] && hide_libressl -R
fi

_check=(libvidstab.a vidstab.pc)
if [[ $ffmpeg != no ]] && enabled libvidstab &&
    do_vcs "$SOURCE_REPO_VIDSTAB" vidstab; then
    do_patch "https://github.com/georgmartius/vid.stab/pull/108.patch" am
    do_pacman_install openmp
    do_uninstall include/vid.stab "${_check[@]}"
    do_cmakeinstall
    do_checkIfExist
fi

_check=(libzvbi.{h,{l,}a} zvbi-0.2.pc)
if [[ $ffmpeg != no ]] && enabled libzvbi &&
    do_pkgConfig "zvbi-0.2 = 0.2.35" &&
    do_wget_sf -h 95e53eb208c65ba6667fd4341455fa27 \
        "zapping/zvbi/0.2.35/zvbi-0.2.35.tar.bz2"; then
    do_uninstall "${_check[@]}" zvbi-0.2.pc
    _vlc_zvbi_patches=https://raw.githubusercontent.com/videolan/vlc/master/contrib/src/zvbi
    do_patch "$_vlc_zvbi_patches/zvbi-win32.patch"
    # added by zvbi-win32.patch above, not needed anymore
    sed -i 's;-lpthreadGC2 -lwsock32;;' zvbi-0.2.pc.in
    do_separate_conf --disable-{dvb,bktr,nls,proxy} --without-doxygen
    cd_safe src
    do_makeinstall
    cd_safe ..
    log pkgconfig make SUBDIRS=. install
    do_checkIfExist
    unset _vlc_zvbi_patches
fi


if [[ $ffmpeg != no ]] && enabled_any frei0r ladspa; then
    _check=(libdl.a dlfcn.h)
    if do_vcs "$SOURCE_REPO_DLFCN"; then
        do_uninstall "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi

    _check=(frei0r.{h,pc})
    if do_vcs "$SOURCE_REPO_FREI0R"; then
        sed -i 's/find_package (Cairo)//' "CMakeLists.txt"
        do_uninstall lib/frei0r-1 "${_check[@]}"
        do_pacman_install gavl
        do_cmakeinstall -DWITHOUT_OPENCV=on
        do_checkIfExist
    fi
fi

_check=(DeckLinkAPI.h DeckLinkAPIVersion.h DeckLinkAPI_i.c)
if [[ $ffmpeg != no ]] && enabled decklink &&
    do_vcs "$SOURCE_REPO_DECKLINK"; then
    do_makeinstall PREFIX="$LOCALDESTDIR"
    do_checkIfExist
fi

_check=(libmfx.{{l,}a,pc})
if [[ $ffmpeg != no ]] && enabled libmfx &&
    do_vcs "$SOURCE_REPO_LIBMFX" libmfx; then
    do_autoreconf
    do_uninstall include/mfx "${_check[@]}"
    do_separate_confmakeinstall
    do_checkIfExist
fi

_check=(AMF/core/Version.h)
if [[ $ffmpeg != no ]] && { enabled amf || ! disabled_any autodetect amf; } &&
    do_vcs "$SOURCE_REPO_AMF"; then
    do_uninstall include/AMF
    cd_safe amf/public/include
    install -D -p -t "$LOCALDESTDIR/include/AMF/core" core/*.h
    install -D -p -t "$LOCALDESTDIR/include/AMF/components" components/*.h
    do_checkIfExist
fi

_check=(libgpac_static.a bin-video/{MP4Box,gpac}.exe)
if [[ $mp4box = y ]] && do_vcs "$SOURCE_REPO_GPAC"; then
    do_uninstall include/gpac "${_check[@]}"
    git grep -PIl "\xC2\xA0" | xargs -r sed -i 's/\xC2\xA0/ /g'
    LDFLAGS+=" -L$LOCALDESTDIR/lib -L$MINGW_PREFIX/lib" \
        do_separate_conf --static-bin --static-build --static-modules --enable-all
    do_make
    log "install" make install-lib
    do_install bin/gcc/MP4Box.exe bin/gcc/gpac.exe bin-video/
    do_checkIfExist
fi

_check=(SvtHevcEnc.pc libSvtHevcEnc.a svt-hevc/EbApi.h
    bin-video/SvtHevcEncApp.exe)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libsvthevc
elif { [[ $svthevc = y ]] || enabled libsvthevc; } &&
    do_vcs "$SOURCE_REPO_SVTHEVC"; then
    do_uninstall "${_check[@]}" include/svt-hevc
    do_cmakeinstall video -DUNIX=OFF
    do_checkIfExist
fi

_check=(bin-video/SvtAv1{Enc,Dec}App.exe
    libSvtAv1{Enc,Dec}.a SvtAv1{Enc,Dec}.pc)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libsvtav1
elif { [[ $svtav1 = y ]] || enabled libsvtav1; } &&
    do_vcs "$SOURCE_REPO_SVTAV1"; then
    do_uninstall include/svt-av1 "${_check[@]}" include/svt-av1
    do_cmakeinstall video -DUNIX=OFF
    do_checkIfExist
fi

_check=(bin-video/SvtVp9EncApp.exe
    libSvtVp9Enc.a SvtVp9Enc.pc)
if [[ $bits = 32bit ]]; then
    do_removeOption --enable-libsvtvp9
elif { [[ $svtvp9 = y ]] || enabled libsvtvp9; } &&
    do_vcs "$SOURCE_REPO_SVTVP9"; then
    do_uninstall include/svt-vp9 "${_check[@]}" include/svt-vp9
    do_cmakeinstall video -DUNIX=OFF
    do_checkIfExist
fi

_check=(xvc.pc xvc{enc,dec}.h libxvc{enc,dec}.a bin-video/xvc{enc,dec}.exe)
if [[ $xvc == y ]] &&
    do_vcs "$SOURCE_REPO_XVC"; then
    do_uninstall "${_check[@]}"
    do_cmakeinstall video -DBUILD_TESTS=OFF -DENABLE_ASSERTIONS=OFF
    do_checkIfExist
fi

if [[ $x264 != no ]] ||
    { [[ $ffmpeg != no ]] && enabled libx264; }; then
    _check=(x264{,_config}.h libx264.a x264.pc)
    [[ $standalone = y ]] && _check+=(bin-video/x264.exe)
    _bitdepth=$(get_api_version x264_config.h BIT_DEPTH)
    if do_vcs "$SOURCE_REPO_X264" ||
        [[ $x264 = o8   && $_bitdepth =~ (0|10) ]] ||
        [[ $x264 = high && $_bitdepth =~ (0|8) ]] ||
        [[ $x264 =~ (yes|full|shared|fullv) && "$_bitdepth" != 0 ]]; then

        extracommands=("--host=$MINGW_CHOST" "--prefix=$LOCALDESTDIR"
            "--bindir=$LOCALDESTDIR/bin-video")

        # light ffmpeg build
        old_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
        PKG_CONFIG_PATH=$LOCALDESTDIR/opt/lightffmpeg/lib/pkgconfig:$MINGW_PREFIX/lib/pkgconfig
        unset_extra_script
        if [[ $standalone = y && $x264 =~ (full|fullv) ]]; then
            _check=("$LOCALDESTDIR"/opt/lightffmpeg/lib/pkgconfig/libav{codec,format}.pc)
            do_vcs "$ffmpegPath"
            do_patch "https://patchwork.ffmpeg.org/series/8130/mbox/" am
            do_uninstall "$LOCALDESTDIR"/opt/lightffmpeg
            [[ -f config.mak ]] && log "distclean" make distclean
            create_build_dir light
            if [[ $x264 = fullv ]]; then
                mapfile -t audio_codecs < <(
                    sed -n '/audio codecs/,/external libraries/p' ../libavcodec/allcodecs.c |
                    sed -n 's/^[^#]*extern.* *ff_\([^ ]*\)_decoder;/\1/p')
                config_path=.. LDFLAGS+=" -L$MINGW_PREFIX/lib" \
                    do_configure "${FFMPEG_BASE_OPTS[@]}" \
                    --prefix="$LOCALDESTDIR/opt/lightffmpeg" \
                    --disable-{programs,devices,filters,encoders,muxers,debug,sdl2,network,protocols,doc} \
                    --enable-protocol=file,pipe \
                    --disable-decoder="$(IFS=, ; echo "${audio_codecs[*]}")" --enable-gpl \
                    --disable-bsf=aac_adtstoasc,text2movsub,noise,dca_core,mov2textsub,mp3_header_decompress \
                    --disable-autodetect --enable-{lzma,bzlib,zlib}
                unset audio_codecs
            else
                config_path=.. LDFLAGS+=" -L$MINGW_PREFIX/lib" \
                    do_configure "${FFMPEG_BASE_OPTS[@]}" \
                    --prefix="$LOCALDESTDIR/opt/lightffmpeg" \
                    --disable-{programs,devices,filters,encoders,muxers,debug,sdl2,doc} --enable-gpl
            fi
            do_makeinstall
            files_exist "${_check[@]}" && touch "build_successful${bits}_light"
            unset_extra_script

            _check=("$LOCALDESTDIR"/opt/lightffmpeg/lib/pkgconfig/ffms2.pc bin-video/ffmsindex.exe)
            if do_vcs "$SOURCE_REPO_FFMS2"; then
                do_uninstall "${_check[@]}"
                sed -i 's/Libs.private.*/& -lstdc++/;s/Cflags.*/& -DFFMS_STATIC/' ffms2.pc.in
                do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/ffms2/0001-ffmsindex-fix-linking-issues.patch" am
                mkdir -p src/config
                do_autoreconf
                do_separate_confmakeinstall video --prefix="$LOCALDESTDIR/opt/lightffmpeg"
                do_checkIfExist
            fi
            cd_safe "$LOCALBUILDDIR"/x264-git
        else
            extracommands+=(--disable-lavf --disable-ffms)
        fi

        if [[ $standalone = y ]]; then
            _check=("$LOCALDESTDIR/opt/lightffmpeg/lib/pkgconfig/liblsmash.pc")
            if do_vcs "$SOURCE_REPO_LIBLSMASH" liblsmash; then
                [[ -f config.mak ]] && log "distclean" make distclean
                do_uninstall "${_check[@]}"
                create_build_dir
                log configure ../configure --prefix="$LOCALDESTDIR/opt/lightffmpeg"
                do_make install-lib
                do_checkIfExist
            fi
            cd_safe "$LOCALBUILDDIR"/x264-git
        else
            extracommands+=(--disable-cli)
        fi

        _check=(x264{,_config}.h x264.pc)
        [[ $standalone = y ]] && _check+=(bin-video/x264.exe)
        [[ -f config.h ]] && log "distclean" make distclean

        x264_build=$(grep ' X264_BUILD ' x264.h | cut -d' ' -f3)
        if [[ $x264 = shared ]]; then
            extracommands+=(--enable-shared)
            _check+=(libx264.dll.a bin-video/libx264-"${x264_build}".dll)
        else
            extracommands+=(--enable-static)
            _check+=(libx264.a)
        fi

        case $x264 in
        high) extracommands+=("--bit-depth=10") ;;
        o8) extracommands+=("--bit-depth=8") ;;
        *) extracommands+=("--bit-depth=all") ;;
        esac

        do_uninstall "${_check[@]}"
        check_custom_patches
        create_build_dir
        extra_script pre configure
        PKGCONFIG="$PKG_CONFIG" CFLAGS="${CFLAGS// -O2 / }" \
            log configure ../configure "${extracommands[@]}"
        extra_script post configure
        do_make
        do_makeinstall
        do_checkIfExist
        PKG_CONFIG_PATH=$old_PKG_CONFIG_PATH
        unset extracommands x264_build old_PKG_CONFIG_PATH
    fi
    unset _bitdepth
else
    pc_exists x264 || do_removeOption --enable-libx264
fi

_check=(x265{,_config}.h libx265.a x265.pc)
[[ $standalone = y ]] && _check+=(bin-video/x265.exe)
if [[ ! $x265 = n ]] && do_vcs "$SOURCE_REPO_X265"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/x265/0001-cmake-split-absolute-library-paths-to-L-and-l.patch" am
    do_uninstall libx265{_main10,_main12}.a bin-video/libx265_main{10,12}.dll "${_check[@]}"
    [[ $bits = 32bit ]] && assembly=-DENABLE_ASSEMBLY=OFF
    [[ $x265 = d ]] && xpsupport=-DWINXP_SUPPORT=ON

    build_x265() {
        create_build_dir
        local build_root=$PWD
        mkdir -p {8,10,12}bit

    do_x265_cmake() {
        do_print_progress "Building $1" && shift 1
        extra_script pre cmake
        log "cmake" cmake "$(get_first_subdir -f)/source" -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$LOCALDESTDIR" -DBIN_INSTALL_DIR="$LOCALDESTDIR/bin-video" \
        -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DHIGH_BIT_DEPTH=ON \
        -DENABLE_HDR10_PLUS=ON $xpsupport -DCMAKE_CXX_COMPILER="$LOCALDESTDIR/bin/${CXX#ccache }.bat" \
        -DCMAKE_TOOLCHAIN_FILE="$LOCALDESTDIR/etc/toolchain.cmake" "$@"
        extra_script post cmake
        do_ninja
    }
    [[ $standalone = y ]] && cli=-DENABLE_CLI=ON

    if [[ $x265 =~ (o12|s|d|y) ]]; then
        cd_safe "$build_root/12bit"
        if [[ $x265 = s ]]; then
            do_x265_cmake "shared 12-bit lib" $assembly -DENABLE_SHARED=ON -DMAIN12=ON
            do_install libx265.dll bin-video/libx265_main12.dll
            _check+=(bin-video/libx265_main12.dll)
        elif [[ $x265 = o12 ]]; then
            do_x265_cmake "12-bit lib/bin" $assembly $cli -DMAIN12=ON
        else
            do_x265_cmake "12-bit lib for multilib" $assembly -DEXPORT_C_API=OFF -DMAIN12=ON
            cp libx265.a ../8bit/libx265_main12.a
        fi
    fi

    if [[ $x265 =~ (o10|s|d|y) ]]; then
        cd_safe "$build_root/10bit"
        if [[ $x265 = s ]]; then
            do_x265_cmake "shared 10-bit lib" $assembly -DENABLE_SHARED=ON
            do_install libx265.dll bin-video/libx265_main10.dll
            _check+=(bin-video/libx265_main10.dll)
        elif [[ $x265 = o10 ]]; then
            do_x265_cmake "10-bit lib/bin" $assembly $cli
        else
            do_x265_cmake "10-bit lib for multilib" $assembly -DEXPORT_C_API=OFF
            cp libx265.a ../8bit/libx265_main10.a
        fi
    fi

    if [[ $x265 =~ (o8|s|d|y) ]]; then
        cd_safe "$build_root/8bit"
        if [[ $x265 = s || $x265 = o8 ]]; then
            do_x265_cmake "8-bit lib/bin" $cli -DHIGH_BIT_DEPTH=OFF
        else
            do_x265_cmake "multilib lib/bin" -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
                -DEXTRA_LINK_FLAGS=-L. $cli -DHIGH_BIT_DEPTH=OFF -DLINKED_{10,12}BIT=ON
            mv libx265.a libx265_main.a
            ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
        fi
    fi
    }
    build_x265
    cpuCount=1 log "install" ninja install
    if [[ $standalone = y && $x265 = d ]]; then
        cd_safe "$(get_first_subdir -f)"
        do_uninstall bin-video/x265-numa.exe
        do_print_progress "Building NUMA version of binary"
        xpsupport="" build_x265
        do_install x265.exe bin-video/x265-numa.exe
        _check+=(bin-video/x265-numa.exe)
    fi
    do_checkIfExist
    unset xpsupport assembly cli
else
    pc_exists x265 || do_removeOption "--enable-libx265"
fi
pc_exists x265 && sed -i 's|-lmingwex||g' "$(file_installed x265.pc)"

_check=(xvid.h libxvidcore.a bin-video/xvid_encraw.exe)
if enabled libxvid && [[ $standalone = y ]] &&
    do_vcs "$SOURCE_REPO_XVID"; then
    do_patch "https://github.com/m-ab-s/xvid/compare/lighde.patch" am
    do_pacman_remove xvidcore
    do_uninstall "${_check[@]}"
    cd_safe xvidcore/build/generic
    log "bootstrap" ./bootstrap.sh
    do_configure
    do_make
    do_install ../../src/xvid.h include/
    do_install '=build/libxvidcore.a' libxvidcore.a
    do_install '=build/libxvidcore.dll' bin-video/
    cd_safe ../../examples
    do_make xvid_encraw
    do_install xvid_encraw.exe bin-video/
    do_checkIfExist
fi

_check=(ffnvcodec/nvEncodeAPI.h ffnvcodec.pc)
if [[ $ffmpeg != no ]] && { enabled ffnvcodec ||
    ! disabled_any ffnvcodec autodetect || ! mpv_disabled cuda-hwaccel; } &&
    do_vcs "$SOURCE_REPO_FFNVCODEC" ffnvcodec; then
    do_makeinstall PREFIX="$LOCALDESTDIR"
    do_checkIfExist
fi

_check=(libsrt.a srt.pc srt/srt.h)
[[ $standalone = y ]] && _check+=(bin-video/srt-live-transmit.exe)
if enabled libsrt && do_vcs "$SOURCE_REPO_SRT"; then
    do_pacman_install openssl
    hide_libressl
    do_cmakeinstall video -DENABLE_SHARED=off -DENABLE_SUFLIP=off \
        -DENABLE_EXAMPLES=off -DUSE_OPENSSL_PC=on -DUSE_STATIC_LIBSTDCXX=ON
    hide_libressl -R
    do_checkIfExist
fi

_check=(librist.{a,pc} librist/librist.h)
[[ $standalone = y ]] && _check+=(bin-global/rist{sender,receiver,2rist,srppasswd}.exe)
if enabled librist && do_vcs "$SOURCE_REPO_LIBRIST"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/librist/0001-Workaround-fixes-for-cJSON-symbol-collision.patch" am
    do_uninstall include/librist "${_check[@]}"
    extracommands=("-Ddisable_json=true")
    [[ $standalone = y ]] || extracommands+=("-Dbuilt_tools=false")
    do_mesoninstall global -Dhave_mingw_pthreads=true -Dtest=false "${extracommands[@]}"
    do_checkIfExist
fi

if  { ! mpv_disabled vapoursynth || enabled vapoursynth; }; then
    _python_ver=3.11.0
    _python_lib=python311
    [[ $bits = 32bit ]] && _arch=win32 || _arch=amd64
    _check=("lib$_python_lib.a")
    if files_exist "${_check[@]}"; then
        do_print_status "python $_python_ver" "$green" "Up-to-date"
    elif do_wget "https://www.python.org/ftp/python/$_python_ver/python-$_python_ver-embed-$_arch.zip"; then
        gendef "$_python_lib.dll" >/dev/null 2>&1
        dlltool -y "lib$_python_lib.a" -d "$_python_lib.def"
        [[ -f lib$_python_lib.a ]] && do_install "lib$_python_lib.a"
        do_checkIfExist
    fi

    _vsver=61
    _check=(lib{vapoursynth,vsscript}.a vapoursynth{,-script}.pc vapoursynth/{VS{Helper,Script},VapourSynth}.h)
    if pc_exists "vapoursynth = $_vsver" && files_exist "${_check[@]}"; then
        do_print_status "vapoursynth R$_vsver" "$green" "Up-to-date"
    elif do_wget "https://github.com/vapoursynth/vapoursynth/releases/download/R$_vsver/VapourSynth${bits%bit}-Portable-R$_vsver.7z"; then
        do_uninstall {vapoursynth,vsscript}.lib include/vapoursynth "${_check[@]}"
        do_install sdk/include/*.h include/vapoursynth/

        create_build_dir
        declare -A _pc_vars=(
            [vapoursynth-name]=vapoursynth
            [vapoursynth-description]='A frameserver for the 21st century'
            [vapoursynth-cflags]="-DVS_CORE_EXPORTS"

            [vsscript-name]=vapoursynth-script
            [vsscript-description]='Library for interfacing VapourSynth with Python'
            [vsscript-private]="-l$_python_lib -lstdc++"
        )
        for _file in vapoursynth vsscript; do
            gendef - "../$_file.dll" 2>/dev/null |
                sed -E 's|^_||;s|@[1-9]+$||' > "${_file}.def"
            # shellcheck disable=SC2046
            dlltool -y "lib${_file}.a" -d "${_file}.def" \
                $([[ $bits = 32bit ]] && echo "-U") 2>/dev/null
            [[ -f lib${_file}.a ]] && do_install "lib${_file}.a"
            # shellcheck disable=SC2016
            printf '%s\n' \
               "prefix=$LOCALDESTDIR" \
               'exec_prefix=${prefix}' \
               'libdir=${exec_prefix}/lib' \
               'includedir=${prefix}/include/vapoursynth' \
               "Name: ${_pc_vars[${_file}-name]}" \
               "Description: ${_pc_vars[${_file}-description]}" \
               "Version: $_vsver" \
               "Libs: -L\${libdir} -l${_file}" \
               "Libs.private: ${_pc_vars[${_file}-private]}" \
               "Cflags: -I\${includedir} ${_pc_vars[${_file}-cflags]}" \
               > "${_pc_vars[${_file}-name]}.pc"
        done

        do_install vapoursynth{,-script}.pc lib/pkgconfig/
        do_checkIfExist
    fi
    unset _arch _file _python_lib _python_ver _vsver _pc_vars
else
    mpv_disable vapoursynth
    do_removeOption --enable-vapoursynth
fi

_check=(liblensfun.a lensfun.pc lensfun/lensfun.h)
if [[ $ffmpeg != no ]] && enabled liblensfun &&
    do_vcs "$SOURCE_REPO_LENSFUN"; then
    do_pacman_install glib2
    grep_or_sed liconv "$MINGW_PREFIX/lib/pkgconfig/glib-2.0.pc" 's;-lintl;& -liconv;g'
    do_patch "https://github.com/m-ab-s/mabs-patches/raw/master/lensfun/0001-CMake-exclude-mingw-w64-from-some-msvc-exclusive-thi.patch" am
    do_patch "https://github.com/m-ab-s/mabs-patches/raw/master/lensfun/0002-CMake-don-t-add-glib2-s-includes-as-SYSTEM-dirs.patch" am
    grep_or_sed Libs.private libs/lensfun/lensfun.pc.cmake '/Libs:/ a\Libs.private: -lstdc++'
    do_uninstall "bin-video/lensfun" "${_check[@]}"
    CFLAGS+=" -DGLIB_STATIC_COMPILATION" CXXFLAGS+=" -DGLIB_STATIC_COMPILATION" \
        do_cmakeinstall -DBUILD_STATIC=on -DBUILD_{TESTS,LENSTOOL,DOC}=off \
        -DINSTALL_HELPER_SCRIPTS=off -DCMAKE_INSTALL_DATAROOTDIR="$LOCALDESTDIR/bin-video"
    do_checkIfExist
fi

_check=(bin-video/vvc/{Encoder,Decoder}App.exe)
if [[ $bits = 64bit && $vvc = y ]] &&
    do_vcs "$SOURCE_REPO_VVC" vvc; then
    do_uninstall bin-video/vvc
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/VVCSoftware_VTM/0001-BBuildEnc.cmake-Remove-Werror-for-gcc-and-clang.patch" am
    # patch for easier install of apps
    # probably not of upstream's interest because of how experimental the codec is
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/VVCSoftware_VTM/0002-cmake-allow-installing-apps.patch" am
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/VVCSoftware_VTM/0003-CMake-add-USE_CCACHE-variable-to-disable-using-found.patch" am
    _notrequired=true
    # install to own dir because the binaries' names are too generic
    do_cmakeinstall -DCMAKE_INSTALL_BINDIR="$LOCALDESTDIR"/bin-video/vvc \
        -DBUILD_STATIC=on -DSET_ENABLE_SPLIT_PARALLELISM=ON -DENABLE_SPLIT_PARALLELISM=OFF \
        -DUSE_CCACHE=OFF
    do_checkIfExist
    unset _notrequired
fi

_check=(bin-video/uvg266.exe libuvg266.a uvg266.pc uvg266.h)
if [[ $bits = 64bit && $uvg266 = y ]] &&
    do_vcs "$SOURCE_REPO_UVG266"; then
    do_uninstall version.h "${_check[@]}"
    do_cmakeinstall video -DBUILD_TESTING=OFF
    do_checkIfExist
fi

_check=(bin-video/vvenc{,FF}app.exe
    vvenc/vvenc.h
    libvvenc.{a,pc}
    lib/cmake/vvenc/vvencConfig.cmake)
if [[ $bits = 64bit && $vvenc = y ]] &&
    do_vcs "$SOURCE_REPO_LIBVVENC"; then
    do_uninstall include/vvenc lib/cmake/vvenc "${_check[@]}"
    do_cmakeinstall video -DVVENC_ENABLE_LINK_TIME_OPT=OFF
    do_checkIfExist
fi

_check=(bin-video/vvdecapp.exe
    vvdec/vvdec.h
    libvvdec.{a,pc}
    lib/cmake/vvdec/vvdecConfig.cmake)
if [[ $bits = 64bit && $vvdec = y ]] &&
    do_vcs "$SOURCE_REPO_LIBVVDEC"; then
    do_uninstall include/vvdec lib/cmake/vvdec "${_check[@]}"
    do_cmakeinstall video -DVVDEC_ENABLE_LINK_TIME_OPT=OFF
    do_checkIfExist
fi

_check=(avisynth/avisynth{,_c}.h
        avisynth/avs/{alignment,arch,capi,config,cpuid,minmax,posix,types,win,version}.h)
if [[ $ffmpeg != no ]] && enabled avisynth &&
    do_vcs "$SOURCE_REPO_AVISYNTH"; then
    do_uninstall "${_check[@]}"
    do_cmake -DHEADERS_ONLY=ON
    do_ninja VersionGen
    do_ninjainstall
    do_checkIfExist
fi

_check=(libvulkan.a vulkan.pc vulkan/vulkan.h d3d{kmthk,ukmdt}.h)
if { { [[ $ffmpeg != no ]] && enabled_any vulkan libplacebo; } ||
     { [[ $mpv != n ]] && ! mpv_disabled_any vulkan libplacebo; } } &&
    do_vcs "$SOURCE_REPO_VULKANLOADER" vulkan-loader; then
    _DeadSix27=https://raw.githubusercontent.com/DeadSix27/python_cross_compile_script/master
    _mabs=https://raw.githubusercontent.com/m-ab-s/mabs-patches/master
    _shinchiro=https://raw.githubusercontent.com/shinchiro/mpv-winbuild-cmake/master
    do_uninstall "${_check[@]}"
    do_patch "$_mabs/vulkan-loader/0001-loader-cross-compile-static-linking-hacks.patch" am
    do_patch "$_mabs/vulkan-loader/0002-pc-remove-CMAKE_CXX_IMPLICIT_LINK_LIBRARIES.patch" am
    grep_and_sed VULKAN_LIB_SUFFIX loader/vulkan.pc.in \
            's/@VULKAN_LIB_SUFFIX@//'
    create_build_dir
    log dependencies /usr/bin/python3 ../scripts/update_deps.py --no-build
    cd_safe Vulkan-Headers
        do_print_progress "Installing Vulkan-Headers"
        do_uninstall include/vulkan
        do_cmakeinstall
        do_wget -c -r -q "$_DeadSix27/additional_headers/d3dkmthk.h"
        do_wget -c -r -q "$_DeadSix27/additional_headers/d3dukmdt.h"
        do_install d3d{kmthk,ukmdt}.h include/
    cd_safe "$(get_first_subdir -f)"
    do_print_progress "Building Vulkan-Loader"
    CFLAGS+=" -DSTRSAFE_NO_DEPRECATE" do_cmakeinstall -DBUILD_TESTS=OFF -DUSE_CCACHE=OFF \
    -DUSE_UNSAFE_C_GEN=ON -DVULKAN_HEADERS_INSTALL_DIR="$LOCALDESTDIR" \
    -DBUILD_STATIC_LOADER=ON -DUNIX=OFF -DENABLE_WERROR=OFF
    do_checkIfExist
    unset _DeadSix27 _mabs _shinchiro
fi

_check=(spirv_cross/spirv_cross_c.h spirv-cross.pc libspirv-cross.a)
if { { [[ $mpv != n ]] && ! mpv_disabled libplacebo; } ||
     { [[ $mpv != n ]] && ! mpv_disabled spirv-cross; } ||
     { [[ $ffmpeg != no ]] && enabled libplacebo; } } &&
    do_vcs "$SOURCE_REPO_SPIRV_CROSS"; then
    do_uninstall include/spirv_cross "${_check[@]}" spirv-cross-c-shared.pc libspirv-cross-c-shared.a
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/SPIRV-Cross/0001-add-a-basic-Meson-build-system-for-use-as-a-subproje.patch" am
    sed -i 's/0.13.0/0.48.0/' meson.build
    do_mesoninstall
    do_checkIfExist
fi

_check=(lib{glslang,OSDependent,HLSL,OGLCompiler,SPVRemapper}.a
        libSPIRV{,-Tools{,-opt,-link,-reduce}}.a glslang/SPIRV/GlslangToSpv.h)
if { { [[ $mpv != n ]]  && ! mpv_disabled libplacebo; } ||
     { [[ $ffmpeg != no ]] && enabled_any libplacebo libglslang; } } &&
    do_vcs "$SOURCE_REPO_GLSLANG"; then
    do_uninstall "${_check[@]}"
    log dependencies /usr/bin/python ./update_glslang_sources.py
    do_cmakeinstall -DUNIX=OFF
    do_checkIfExist
fi

_check=(shaderc/shaderc.h libshaderc_combined.a)
    if ! mpv_disabled shaderc &&
        do_vcs "$SOURCE_REPO_SHADERC"; then
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/shaderc/0001-third_party-set-INSTALL-variables-as-cache.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/shaderc/0002-shaderc_util-add-install.patch" am
        do_uninstall "${_check[@]}" include/shaderc include/libshaderc_util

        add_third_party() {
            local repo=$1
            local name=$2
            [[ ! $name ]] && name=${repo##*/} && name=${name%.*}
            local dest=third_party/$name

            if [[ -d $dest/.git ]]; then
                log "$name-reset" git -C "$dest" reset --hard "@{u}"
                log "$name-pull" git -C "$dest" pull
            else
                log "$name-clone" git clone --depth 1 "$repo" "$dest"
            fi
        }

        add_third_party "$SOURCE_REPO_GLSLANG"
        add_third_party "$SOURCE_REPO_SPIRV_TOOLS" spirv-tools
        add_third_party "$SOURCE_REPO_SPIRV_HEADERS" spirv-headers
        add_third_party "$SOURCE_REPO_SPIRV_CROSS" spirv-cross

        # fix python indentation errors from non-existant code review
        grep -ZRlP --include="*.py" '\t' third_party/spirv-tools/ | xargs -r -0 -n1 sed -i 's;\t;    ;g'

        do_cmakeinstall -GNinja -DSHADERC_SKIP_{TESTS,EXAMPLES}=ON -DSHADERC_ENABLE_WERROR_COMPILE=OFF -DSKIP_{GLSLANG,SPIRV_TOOLS,GOOGLETEST}_INSTALL=ON -DSPIRV_HEADERS_SKIP_{INSTALL,EXAMPLES}=ON
        do_checkIfExist
        unset add_third_party
    fi

    file_installed -s shaderc.pc && file_installed -s shaderc_static.pc &&
        mv "$(file_installed shaderc_static.pc)" "$(file_installed shaderc.pc)"

_check=(libplacebo.{a,pc})
_deps=(lib{vulkan,shaderc_combined}.a spirv-cross.pc shaderc/shaderc.h)
if { { [[ $mpv != n ]]  && ! mpv_disabled libplacebo; } ||
     { [[ $ffmpeg != no ]] && enabled libplacebo; } } &&
    do_vcs "$SOURCE_REPO_LIBPLACEBO"; then
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libplacebo/0001-meson-use-shaderc_combined.patch" am
    do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/libplacebo/0002-spirv-cross-use-spirv-cross-instead-of-c-shared.patch" am
    do_pacman_install python-{mako,setuptools}
    do_uninstall "${_check[@]}"
    log -q "git.submodule" git submodule update --init --recursive
    do_mesoninstall -Dvulkan-registry="$LOCALDESTDIR/share/vulkan/registry/vk.xml" -Ddemos=false -Dd3d11=enabled
    do_checkIfExist
fi

enabled openssl && hide_libressl
if [[ $ffmpeg != no ]]; then
    enabled libgsm && do_pacman_install gsm
    enabled libsnappy && do_addOption --extra-libs=-lstdc++ && do_pacman_install snappy
    if enabled libxvid && [[ $standalone = n ]]; then
        do_pacman_install xvidcore
        [[ -f $MINGW_PREFIX/lib/xvidcore.a ]] && mv -f "$MINGW_PREFIX"/lib/{,lib}xvidcore.a
        [[ -f $MINGW_PREFIX/lib/xvidcore.dll.a ]] && mv -f "$MINGW_PREFIX"/lib/xvidcore.dll.a{,.dyn}
    fi
    if enabled libssh; then
        do_pacman_install libssh
        do_addOption --extra-cflags=-DLIBSSH_STATIC "--extra-ldflags=-Wl,--allow-multiple-definition"
        grep_or_sed "Requires.private" "$MINGW_PREFIX"/lib/pkgconfig/libssh.pc \
            "/Libs:/ i\Requires.private: zlib libssl"
    fi
    enabled libtheora && do_pacman_install libtheora
    if enabled libcdio; then
        do_pacman_install libcdio-paranoia
        grep -ZlER -- "-R/mingw\S+" "$MINGW_PREFIX"/lib/pkgconfig/* | xargs -r -0 sed -ri 's;-R/mingw\S+;;g'
    fi
    enabled libcaca && do_addOption --extra-cflags=-DCACA_STATIC && do_pacman_install libcaca
    enabled libmodplug && do_addOption --extra-cflags=-DMODPLUG_STATIC && do_pacman_install libmodplug
    enabled libopenjpeg && do_pacman_install openjpeg2
    if enabled libopenh264; then
        do_pacman_install openh264
        if [[ -f $MINGW_PREFIX/lib/libopenh264.dll.a.dyn ]]; then
            mv -f "$MINGW_PREFIX"/lib/libopenh264.a{,.bak}
            mv -f "$MINGW_PREFIX"/lib/libopenh264.{dll.a.dyn,a}
        fi
        [[ -f $MINGW_PREFIX/lib/libopenh264.dll.a ]] && mv -f "$MINGW_PREFIX"/lib/libopenh264.{dll.,}a
        _openh264_ver=2.3.1
        if test_newer "$MINGW_PREFIX"/lib/libopenh264.dll.a "$LOCALDESTDIR/bin-video/libopenh264.dll" ||
            ! get_dll_version "$LOCALDESTDIR/bin-video/libopenh264.dll" | grep -q "$_openh264_ver"; then
            pushd "$LOCALDESTDIR/bin-video" >/dev/null || do_exit_prompt "Did you delete the bin-video folder?"
            if [[ $bits = 64bit ]]; then
              _sha256=3d5bc8ce7a57f956f445f9aa98015d49c59623d89d78a9139ed8728ed853e197
            else
              _sha256=7e9c5a31b2e1dbd1265bb96c6a6c8813c0de8d593b5a0b2476e316f27c280be7
            fi
            do_wget -c -r -q -h $_sha256 \
            "http://ciscobinary.openh264.org/openh264-${_openh264_ver}-win${bits%bit}.dll.bz2" \
                libopenh264.dll.bz2
            [[ -f libopenh264.dll.bz2 ]] && bunzip2 -f libopenh264.dll.bz2
            unset _sha256 _openh264_ver
            popd >/dev/null || do_exit_prompt "Did you delete the previous folder?"
        fi
    fi
    enabled chromaprint && do_addOption --extra-cflags=-DCHROMAPRINT_NODLL --extra-libs=-lstdc++ &&
        { do_pacman_remove fftw; do_pacman_install chromaprint; }
    if enabled libzmq; then
        do_pacman_install zeromq
        grep_or_sed ws2_32 "$MINGW_PREFIX"/lib/pkgconfig/libzmq.pc \
            's/-lpthread/& -lws2_32/'
        do_addOption --extra-cflags=-DZMQ_STATIC
    fi
    enabled frei0r && do_addOption --extra-libs=-lpsapi
    enabled libxml2 && do_addOption --extra-cflags=-DLIBXML_STATIC
    enabled ladspa && do_pacman_install ladspa-sdk
    if enabled vapoursynth && pc_exists "vapoursynth-script >= 42"; then
        _ver=$($PKG_CONFIG --modversion vapoursynth-script)
        do_simple_print "${green}Compiling FFmpeg with Vapoursynth R${_ver}${reset}"
        do_simple_print "${orange}FFmpeg will need vapoursynth.dll and vsscript.dll to run using vapoursynth demuxers"'!'"${reset}"
        unset _ver
    elif enabled vapoursynth; then
        do_removeOption --enable-vapoursynth
        do_simple_print "${red}Update to at least Vapoursynth R42 to use with FFmpeg${reset}"
    fi
    disabled autodetect && enabled iconv && do_addOption --extra-libs=-liconv

    do_hide_all_sharedlibs

    _check=(libavutil.pc)
    disabled_any avfilter ffmpeg || _check+=(bin-video/ffmpeg.exe)
    if [[ $ffmpeg =~ shared ]]; then
        _check+=(libavutil.dll.a)
    else
        _check+=(libavutil.a)
        [[ $ffmpeg =~ both ]] && _check+=(bin-video/ffmpegSHARED)
    fi
    # todo: make this more easily customizable
    [[ $ffmpegUpdate = y ]] && enabled_any lib{aom,tesseract,vmaf,x265,vpx} &&
        _deps=(lib{aom,tesseract,vmaf,x265,vpx}.a)
    if do_vcs "$ffmpegPath"; then
        do_changeFFmpegConfig "$license"
        [[ -f ffmpeg_extra.sh ]] && source ffmpeg_extra.sh
        if enabled libsvthevc; then
            do_patch "https://raw.githubusercontent.com/OpenVisualCloud/SVT-HEVC/master/ffmpeg_plugin/master-0001-lavc-svt_hevc-add-libsvt-hevc-encoder-wrapper.patch" am ||
                do_removeOption --enable-libsvthevc
        fi
        if enabled libsvtvp9; then
            do_patch "https://raw.githubusercontent.com/OpenVisualCloud/SVT-VP9/master/ffmpeg_plugin/master-0001-Add-ability-for-ffmpeg-to-run-svt-vp9.patch" am ||
                do_removeOption --enable-libsvtvp9
        fi

        enabled libsvthevc || do_removeOption FFMPEG_OPTS_SHARED "--enable-libsvthevc"
        enabled libsvtav1 || do_removeOption FFMPEG_OPTS_SHARED "--enable-libsvtav1"
        enabled libsvtvp9 || do_removeOption FFMPEG_OPTS_SHARED "--enable-libsvtvp9"

        enabled vapoursynth && do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/ffmpeg/0001-Add-Alternative-VapourSynth-demuxer.patch" am

        if enabled openal &&
            pc_exists "openal"; then
            OPENAL_LIBS=$($PKG_CONFIG --libs openal)
            export OPENAL_LIBS
            do_addOption "--extra-cflags=-DAL_LIBTYPE_STATIC"
            do_addOption FFMPEG_OPTS_SHARED "--extra-cflags=-DAL_LIBTYPE_STATIC"
            for _openal_flag in $($PKG_CONFIG --cflags openal); do
                do_addOption "--extra-cflags=$_openal_flag"
            done
            unset _openal_flag
        fi

        if [[ ${#FFMPEG_OPTS[@]} -gt 35 ]]; then
            # remove redundant -L and -l flags from extralibs
            do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/ffmpeg/0001-configure-deduplicate-linking-flags.patch" am
        fi

        do_patch "https://patchwork.ffmpeg.org/series/8130/mbox/" am

        _patches=$(git rev-list origin/master.. --count)
        [[ $_patches -gt 0 ]] &&
            do_addOption "--extra-version=g$(git rev-parse --short origin/master)+$_patches"

        _uninstall=(include/libav{codec,device,filter,format,util,resample}
            include/lib{sw{scale,resample},postproc}
            libav{codec,device,filter,format,util,resample}.{dll.a,a,pc}
            lib{sw{scale,resample},postproc}.{dll.a,a,pc}
            "$LOCALDESTDIR"/lib/av{codec,device,filter,format,util}-*.def
            "$LOCALDESTDIR"/lib/{sw{scale,resample},postproc}-*.def
            "$LOCALDESTDIR"/bin-video/av{codec,device,filter,format,util}-*.dll
            "$LOCALDESTDIR"/bin-video/{sw{scale,resample},postproc}-*.dll
            "$LOCALDESTDIR"/bin-video/av{codec,device,filter,format,util}.lib
            "$LOCALDESTDIR"/bin-video/{sw{scale,resample},postproc}.lib
            )
        _check=()
        sedflags="prefix|bindir|extra-version|pkg-config-flags"

        # --build-suffix handling
        opt_exists FFMPEG_OPTS "^--build-suffix=[a-zA-Z0-9-]+$" &&
            build_suffix=$(printf '%s\n' "${FFMPEG_OPTS[@]}" |
                sed -rn '/build-suffix=/{s;.+=(.+);\1;p}') ||
                build_suffix=""

        if [[ $ffmpeg =~ both ]]; then
            _check+=(bin-video/ffmpegSHARED/lib/"libavutil${build_suffix}.dll.a")
            FFMPEG_OPTS_SHARED+=("--prefix=$LOCALDESTDIR/bin-video/ffmpegSHARED")
        elif [[ $ffmpeg =~ shared ]]; then
            _check+=("libavutil${build_suffix}".{dll.a,pc})
            FFMPEG_OPTS_SHARED+=("--prefix=$LOCALDESTDIR"
                "--bindir=$LOCALDESTDIR/bin-video"
                "--shlibdir=$LOCALDESTDIR/bin-video")
        fi
        ! disabled_any debug "debug=gdb" &&
            ffmpeg_cflags=$(sed -r 's/ (-O[1-3]|-mtune=\S+)//g' <<< "$CFLAGS")

        # shared
        if [[ $ffmpeg != static ]] && [[ ! -f build_successful${bits}_shared ]]; then
            do_print_progress "Compiling ${bold}shared${reset} FFmpeg"
            do_uninstall bin-video/ffmpegSHARED "${_uninstall[@]}"
            [[ -f config.mak ]] && log "distclean" make distclean
            create_build_dir shared
            config_path=.. CFLAGS="${ffmpeg_cflags:-$CFLAGS}" \
            LDFLAGS+=" -L$LOCALDESTDIR/lib -L$MINGW_PREFIX/lib" \
                do_configure \
                --disable-static --enable-shared "${FFMPEG_OPTS_SHARED[@]}"
            # cosmetics
            sed -ri "s/ ?--($sedflags)=(\S+[^\" ]|'[^']+')//g" config.h
            do_make && do_makeinstall
            cd_safe ..
            files_exist "${_check[@]}" && touch "build_successful${bits}_shared"
        fi

        # static
        if [[ ! $ffmpeg =~ shared ]] && _check=(libavutil.{a,pc}); then
            do_print_progress "Compiling ${bold}static${reset} FFmpeg"
            [[ -f config.mak ]] && log "distclean" make distclean
            if ! disabled_any programs avcodec avformat; then
                if ! disabled swresample; then
                    disabled_any avfilter ffmpeg || _check+=(bin-video/ffmpeg.exe)
                    if { disabled autodetect && enabled_any sdl2 ffplay; } ||
                        { ! disabled autodetect && ! disabled_any sdl2 ffplay; }; then
                        _check+=(bin-video/ffplay.exe)
                    fi
                fi
                disabled ffprobe || _check+=(bin-video/ffprobe.exe)
            fi
            do_uninstall bin-video/ff{mpeg,play,probe}.exe{,.debug} "${_uninstall[@]}"
            create_build_dir static
            config_path=.. CFLAGS="${ffmpeg_cflags:-$CFLAGS}" \
            cc=$CC cxx=$CXX LDFLAGS+=" -L$LOCALDESTDIR/lib -L$MINGW_PREFIX/lib" \
                do_configure \
                --bindir="$LOCALDESTDIR/bin-video" "${FFMPEG_OPTS[@]}"
            # cosmetics
            sed -ri "s/ ?--($sedflags)=(\S+[^\" ]|'[^']+')//g" config.h
            do_make && do_makeinstall
            ! disabled_any debug "debug=gdb" &&
                create_debug_link "$LOCALDESTDIR"/bin-video/ff{mpeg,probe,play}.exe
            cd_safe ..
        fi
        do_checkIfExist
        [[ -f $LOCALDESTDIR/bin-video/ffmpeg.exe ]] &&
            create_winpty_exe ffmpeg "$LOCALDESTDIR"/bin-video/
        unset ffmpeg_cflags build_suffix
    fi
fi

# static do_vcs just for svn
check_mplayer_updates() {
    cd_safe "$LOCALBUILDDIR"
    if [[ ! -d mplayer-svn/.svn ]]; then
        rm -rf mplayer-svn
        do_print_progress "  Running svn clone for mplayer"
        svn_clone() (
            set -x
            svn --non-interactive checkout -r HEAD svn://svn.mplayerhq.hu/mplayer/trunk mplayer-svn &&
                [[ -d mplayer-svn/.svn ]]
        )
        if svn --non-interactive ls svn://svn.mplayerhq.hu/mplayer/trunk > /dev/null 2>&1 &&
            log -q "svn.clone" svn_clone; then
            touch mplayer-svn/recently_{updated,checked}
        else
            echo "mplayer svn seems to be down"
            echo "Try again later or <Enter> to continue"
            do_prompt "if you're sure nothing depends on it."
            return
        fi
        unset svn_clone
    fi

    cd_safe mplayer-svn

    oldHead=$(svn info --show-item last-changed-revision .)
    log -q "svn.reset" svn revert --recursive .
    if ! [[ -f recently_checked && recently_checked -nt $LOCALBUILDDIR/last_run ]]; then
        do_print_progress "  Running svn update for mplayer"
        log -q "svn.update" svn update -r HEAD
        newHead=$(svn info --show-item last-changed-revision .)
        touch recently_checked
    else
        newHead="$oldHead"
    fi

    rm -f custom_updated
    check_custom_patches

    if [[ $oldHead != "$newHead" || -f custom_updated ]]; then
        touch recently_updated
        rm -f ./build_successful{32,64}bit{,_*}
        if [[ $build32$build64$bits == yesyes64bit ]]; then
            new_updates="yes"
            new_updates_packages="$new_updates_packages [mplayer]"
        fi
        printf 'mplayer\n' >> "$LOCALBUILDDIR"/newchangelog
        do_print_status "┌ mplayer svn" "$orange" "Updates found"
    elif [[ -f recently_updated && ! -f build_successful$bits ]]; then
        do_print_status "┌ mplayer svn" "$orange" "Recently updated"
    elif ! files_exist "${_check[@]}"; then
        do_print_status "┌ mplayer svn" "$orange" "Files missing"
    else
        do_print_status "mplayer svn" "$green" "Up-to-date"
        [[ ! -f recompile ]] &&
            return 1
        do_print_status "┌ mplayer svn" "$orange" "Forcing recompile"
        do_print_status prefix "$bold├$reset " "Found recompile flag" "$orange" "Recompiling"
    fi
    return 0
}

_check=(bin-video/m{player,encoder}.exe)
if [[ $mplayer = y ]] && check_mplayer_updates; then
    [[ $license != nonfree || $faac == n ]] && faac_opts=(--disable-faac)
    do_uninstall "${_check[@]}"
    [[ -f config.mak ]] && log "distclean" make distclean
    if [[ ! -d ffmpeg ]] &&
        ! { [[ -d $LOCALBUILDDIR/ffmpeg-git ]] &&
        git clone -q "$LOCALBUILDDIR/ffmpeg-git" ffmpeg; } &&
        ! git clone "$ffmpegPath" ffmpeg; then
        rm -rf ffmpeg
        printf '%s\n' \
            "Failed to get a FFmpeg checkout" \
            "Please try again or put FFmpeg source code copy into ffmpeg/ manually." \
            "Nightly snapshot: http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2" \
            "Either re-run the script or extract above to inside /build/mplayer-svn."
        do_prompt "<Enter> to continue or <Ctrl+c> to exit the script"
    fi
    [[ ! -d ffmpeg ]] && compilation_fail "Finding valid ffmpeg dir"
    [[ -d ffmpeg/.git ]] && {
        git -C ffmpeg fetch -q origin
        git -C ffmpeg checkout -qf --no-track -B master origin/HEAD
        (
            cd ffmpeg || return
            do_patch "https://patchwork.ffmpeg.org/series/8130/mbox/" am
        )
    }

    grep_or_sed windows libmpcodecs/ad_spdif.c '/#include "mp_msg.h/ a\#include <windows.h>'

    _notrequired=true
    do_configure --bindir="$LOCALDESTDIR"/bin-video \
    --extra-cflags='-fpermissive -DPTW32_STATIC_LIB -O3 -DMODPLUG_STATIC -Wno-int-conversion' \
    --extra-libs="-llzma -liconv -lws2_32 -lpthread -lwinpthread -lpng -lwinmm $($PKG_CONFIG --libs libilbc) \
        $(enabled vapoursynth && $PKG_CONFIG --libs vapoursynth-script)" \
    --extra-ldflags='-Wl,--allow-multiple-definition' --enable-{static,runtime-cpudetection} \
    --disable-{gif,cddb} "${faac_opts[@]}" --with-dvdread-config="$PKG_CONFIG dvdread" \
    --with-freetype-config="$PKG_CONFIG freetype2" --with-dvdnav-config="$PKG_CONFIG dvdnav" &&
        do_makeinstall && do_checkIfExist
    unset _notrequired faac_opts
fi

if [[ $mpv != n ]] && pc_exists libavcodec libavformat libswscale libavfilter; then
    if ! mpv_disabled lua && opt_exists MPV_OPTS "--lua=5.1"; then
        do_pacman_install lua51
    elif ! mpv_disabled lua &&
        _check=(bin-global/luajit.exe libluajit-5.1.a luajit.pc luajit-2.1/lua.h) &&
        do_vcs "$SOURCE_REPO_LUAJIT" luajit; then
        do_pacman_remove luajit lua51
        do_uninstall include/luajit-2.1 lib/lua "${_check[@]}"
        [[ -f src/luajit.exe ]] && log "clean" make clean
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/LuaJIT/0001-Add-win32-UTF-8-filesystem-functions.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/LuaJIT/0002-win32-UTF-8-Remove-va-arg-and-.-and-unused-functions.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/LuaJIT/0003-make-don-t-override-user-provided-CC.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/LuaJIT/0004-pkgconfig-fix-pkg-config-file-for-mingw64.patch" am
        sed -i "s|export PREFIX= /usr/local|export PREFIX=${LOCALDESTDIR}|g" Makefile
        sed -i "s|^prefix=.*|prefix=$LOCALDESTDIR|" etc/luajit.pc
        _luajit_args=("PREFIX=$LOCALDESTDIR" "INSTALL_BIN=$LOCALDESTDIR/bin-global" "INSTALL_TNAME=luajit.exe")
        do_make amalg HOST_CC="$CC" BUILDMODE=static \
            CFLAGS='-D_WIN32_WINNT=0x0602 -DUNICODE' \
            XCFLAGS="-DLUAJIT_ENABLE_LUA52COMPAT$([[ $bits = 64bit ]] && echo " -DLUAJIT_ENABLE_GC64")" \
            "${_luajit_args[@]}"
        do_makeinstall "${_luajit_args[@]}"
        do_checkIfExist
        unset _luajit_args
    fi

    do_pacman_remove uchardet-git
    ! mpv_disabled uchardet && do_pacman_install uchardet
    ! mpv_disabled libarchive && do_pacman_install libarchive
    ! mpv_disabled lcms2 && do_pacman_install lcms2

    do_pacman_remove angleproject-git
    _check=(EGL/egl.h)
    if mpv_enabled egl-angle && do_vcs "$SOURCE_REPO_ANGLE"; then
        do_simple_print "${orange}mpv will need libGLESv2.dll and libEGL.dll to use gpu-context=angle"'!'
        do_simple_print "You can find these in your browser's installation directory, usually."
        do_uninstall include/{EGL,GLES{2,3},KHR,platform} angle_gl.h \
            lib{GLESv2,EGL}.a "${_check[@]}"
        cp -rf include/{EGL,KHR} "$LOCALDESTDIR/include/"
        do_checkIfExist
    elif ! mpv_disabled egl-angle && ! files_exist "${_check[@]}"; then
        mpv_disable egl-angle
    fi

    if ! mpv_disabled vapoursynth && pc_exists "vapoursynth-script >= 24"; then
        _ver=$($PKG_CONFIG --modversion vapoursynth-script)
        do_simple_print "${green}Compiling mpv with Vapoursynth R${_ver}${reset}"
        do_simple_print "${orange}mpv will need vapoursynth.dll and vsscript.dll to use vapoursynth filter"'!'"${reset}"
        unset _ver
    elif ! mpv_disabled vapoursynth; then
        mpv_disable vapoursynth
        do_simple_print "${red}Update to at least Vapoursynth R24 to use with mpv${reset}"
    fi

    _check=(mujs.{h,pc} libmujs.a)
    if ! mpv_disabled javascript &&
        do_vcs "$SOURCE_REPO_MUJS"; then
        do_uninstall bin-global/mujs.exe "${_check[@]}"
        log clean env -i PATH="$PATH" "$(command -v make)" clean
        mujs_targets=(build/release/{mujs.pc,libmujs.a})
        if [[ $standalone != n ]]; then
            mujs_targets+=(build/release/mujs)
            _check+=(bin-global/mujs.exe)
            sed -i "s;-lreadline;$($PKG_CONFIG --libs readline);g" Makefile
        fi
        extra_script pre make
        log "make" env -i PATH="$PATH" TEMP="${TEMP:-/tmp}" CPATH="${CPATH:-}" "$(command -v make)" \
            "${mujs_targets[@]}" prefix="$LOCALDESTDIR" bindir="$LOCALDESTDIR/bin-global"
        extra_script post make
        extra_script pre install
        [[ $standalone != n ]] && do_install build/release/mujs "$LOCALDESTDIR/bin-global"
        do_install build/release/mujs.pc lib/pkgconfig/
        do_install build/release/libmujs.a lib/
        do_install mujs.h include/
        extra_script post install
        grep_or_sed "Requires.private:" "$LOCALDESTDIR/lib/pkgconfig/mujs.pc" \
            's;Version:.*;&\nRequires.private: readline;'
        unset mujs_targets
        do_checkIfExist
    fi

    _check=(mruby.h libmruby{,_core}.a)
    if mpv_enabled mruby && do_vcs "$SOURCE_REPO_MRUBY"; then
        do_uninstall "${_check[@]}" include/mruby mrbconf.h
        log clean make clean
        log make ./minirake "$(pwd)/build/host/lib/libmruby.a"
        do_install build/host/lib/*.a lib/
        cmake -E copy_directory include "$LOCALDESTDIR/include"
        do_checkIfExist
    fi

    _check=()
    ! mpv_disabled cplayer && _check+=(bin-video/mpv.{exe,com})
    mpv_enabled libmpv-shared && _check+=(bin-video/mpv-2.dll)
    mpv_enabled libmpv-static && _check+=(libmpv.a)
    _deps=(lib{ass,avcodec,vapoursynth,shaderc_combined,spirv-cross,placebo}.a "$MINGW_PREFIX"/lib/libuchardet.a)
    if do_vcs "$SOURCE_REPO_MPV"; then
        hide_conflicting_libs
        create_ab_pkgconfig

        log bootstrap /usr/bin/python bootstrap.py
        if [[ -d build ]]; then
            WAF_NO_PREFORK=1 /usr/bin/python waf distclean >/dev/null 2>&1
            do_uninstall bin-video/mpv{.exe,-2.dll}.debug "${_check[@]}"
        fi

        mpv_ldflags=("-L$LOCALDESTDIR/lib" "-L$MINGW_PREFIX/lib")
        if [[ $bits = 64bit ]]; then
            mpv_ldflags+=("-Wl,--image-base,0x140000000,--high-entropy-va")
            if enabled libnpp && [[ -n "$CUDA_PATH" ]]; then
                mpv_cflags=("-I$(cygpath -sm "$CUDA_PATH")/include")
                mpv_ldflags+=("-L$(cygpath -sm "$CUDA_PATH")/lib/x64")
            fi
        fi

        enabled libvidstab && {
            mapfile -d ' ' -t -O "${#mpv_cflags[@]}" mpv_cflags < <($PKG_CONFIG --libs vidstab)
            mapfile -d ' ' -t -O "${#mpv_ldflags[@]}" mpv_ldflags < <($PKG_CONFIG --libs vidstab)
        }
        enabled_any libssh libxavs2 && mpv_ldflags+=("-Wl,--allow-multiple-definition")
        if ! mpv_disabled manpage-build || mpv_enabled html-build; then
            do_pacman_install python-docutils
        fi
        # do_pacman_remove python3-rst2pdf
        # mpv_enabled pdf-build && do_pacman_install python2-rst2pdf

        # rst2pdf is broken
        mpv_disable pdf-build

        [[ -f mpv_extra.sh ]] && source mpv_extra.sh

        mpv_enabled mruby &&
            { git merge --no-edit --no-gpg-sign origin/mruby ||
              git merge --abort && do_removeOption MPV_OPTS "--enable-mruby"; }

        if files_exist libavutil.a; then
            MPV_OPTS+=(--enable-static-build)
        else
            # force pkg-config lookup to look for static requirements
            export PKGCONF_STATIC=yes
            # hacky way of ignoring ffmpeg libs own shared dependencies
            for _avpc in avcodec avdevice avfilter avformat avutil swresample swscale; do
                if [[ -f $LOCALDESTDIR/lib/pkgconfig/lib$_avpc.pc ]]; then
                    sed -i 's;^Requires.private;# &;g' "$LOCALDESTDIR/lib/pkgconfig/lib${_avpc}.pc"
                fi
            done
        fi

        extra_script pre configure
        CFLAGS+=" ${mpv_cflags[*]} -Wno-int-conversion" LDFLAGS+=" ${mpv_ldflags[*]}" \
            RST2MAN="${MINGW_PREFIX}/bin/rst2man" \
            RST2HTML="${MINGW_PREFIX}/bin/rst2html" \
            RST2PDF="${MINGW_PREFIX}/bin/rst2pdf2" \
            PKG_CONFIG="$LOCALDESTDIR/bin/ab-pkg-config" \
            WAF_NO_PREFORK=1 \
            log configure /usr/bin/python waf configure \
            "--prefix=$LOCALDESTDIR" "--bindir=$LOCALDESTDIR/bin-video" \
            "${MPV_OPTS[@]}"
        extra_script post configure

        replace="LIBPATH_lib\1 = ['${LOCALDESTDIR}/lib','${MINGW_PREFIX}/lib']"
        sed -r -i "s:LIBPATH_lib(ass|av(|device|filter)) = .*:$replace:g" ./build/c4che/_cache.py	

        extra_script pre build
        WAF_NO_PREFORK=1 \
            log build /usr/bin/python waf -j "${cpuCount:-1}"
        extra_script post build

        extra_script pre install
        WAF_NO_PREFORK=1 \
            log install /usr/bin/python waf -j1 install ||
            log install /usr/bin/python waf -j1 install
        extra_script post install

        if ! files_exist libavutil.a; then
            # revert hack
            for _avpc in avcodec avdevice avfilter avformat avutil swresample swscale; do
                if [[ -f $LOCALDESTDIR/lib/pkgconfig/lib$_avpc.pc ]]; then
                    sed -ri 's;#.*(Requires.private);\1;g' "$LOCALDESTDIR/lib/pkgconfig/lib${_avpc}.pc"
                fi
            done
        fi

        unset mpv_ldflags replace PKGCONF_STATIC
        hide_conflicting_libs -R
        files_exist share/man/man1/mpv.1 && dos2unix -q "$LOCALDESTDIR"/share/man/man1/mpv.1
        ! mpv_disabled debug-build &&
            create_debug_link "$LOCALDESTDIR"/bin-video/mpv{.exe,-2.dll}
        create_winpty_exe mpv "$LOCALDESTDIR"/bin-video/ "export _started_from_console=yes"
        do_checkIfExist
    fi
fi

if [[ $bmx = y ]]; then
    do_pacman_install uriparser

    _check=(bin-video/MXFDump.exe libMXF-1.0.{{,l}a,pc})
    if do_vcs "$SOURCE_REPO_LIBMXF" libMXF-1.0; then
        do_autogen
        do_uninstall include/libMXF-1.0 "${_check[@]}"
        do_separate_confmakeinstall video --disable-examples
        do_checkIfExist
    fi

    _check=(libMXF++-1.0.{{,l}a,pc})
    _deps=(libMXF-1.0.a)
    if do_vcs "$SOURCE_REPO_LIBMXFPP" libMXF++-1.0; then
        do_autogen
        do_uninstall include/libMXF++-1.0 "${_check[@]}"
        do_separate_confmakeinstall video --disable-examples
        do_checkIfExist
    fi

    _check=(bin-video/{bmxtranswrap,{h264,mov,vc2}dump,mxf2raw,raw2bmx}.exe)
    _deps=("$MINGW_PREFIX"/lib/liburiparser.a lib{MXF{,++}-1.0,curl}.a)
    if do_vcs "$SOURCE_REPO_LIBBMX"; then
        do_autogen
        do_uninstall libbmx-0.1.{{,l}a,pc} bin-video/bmxparse.exe \
            include/bmx-0.1 "${_check[@]}"
        do_separate_confmakeinstall video
        do_checkIfExist
    fi
fi
enabled openssl && hide_libressl -R

if [[ $cyanrip = y ]]; then
    do_pacman_install libcdio-paranoia jansson
    sed -ri 's;-R[^ ]*;;g' "$MINGW_PREFIX/lib/pkgconfig/libcdio.pc"

    _check=(neon/ne_utils.h libneon.a neon.pc)
    if do_vcs "$SOURCE_REPO_NEON"; then
        do_patch "https://github.com/notroj/neon/pull/69.patch" am
        do_uninstall include/neon "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall --disable-{nls,debug,webdav}
        do_checkIfExist
    fi

    _deps=(libneon.a libxml2.a)
    _check=(musicbrainz5/mb5_c.h libmusicbrainz5{,cc}.{a,pc})
    if do_vcs "$SOURCE_REPO_LIBMUSICBRAINZ"; then
        do_uninstall "${_check[@]}" include/musicbrainz5
        do_cmakeinstall
        do_checkIfExist
    fi

    _deps=(libmusicbrainz5.a libcurl.a)
    _check=(bin-audio/cyanrip.exe)
    if do_vcs "$SOURCE_REPO_CYANRIP"; then
        old_PKG_CONFIG_PATH=$PKG_CONFIG_PATH
        _check=("$LOCALDESTDIR"/opt/cyanffmpeg/lib/pkgconfig/libav{codec,format}.pc)
        if flavor=cyan do_vcs "$ffmpegPath"; then
            do_patch "https://patchwork.ffmpeg.org/series/8130/mbox/" am
            do_uninstall "$LOCALDESTDIR"/opt/cyanffmpeg
            [[ -f config.mak ]] && log "distclean" make distclean
            mapfile -t cyan_ffmpeg_opts < <(
                enabled libmp3lame &&
                    printf '%s\n' "--enable-libmp3lame" "--enable-encoder=libmp3lame"
                if enabled libvorbis; then
                    printf '%s\n' "--enable-libvorbis" "--enable-encoder=libvorbis"
                else
                    echo "--enable-encoder=vorbis"
                fi
                if enabled libopus; then
                    printf '%s\n' "--enable-libopus" "--enable-encoder=libopus"
                else
                    echo "--enable-encoder=opus"
                fi
            )
            create_build_dir cyan
            config_path=.. do_configure "${FFMPEG_BASE_OPTS[@]}" \
                --prefix="$LOCALDESTDIR/opt/cyanffmpeg" \
                --disable-{programs,devices,filters,decoders,hwaccels,encoders,muxers} \
                --disable-{debug,protocols,demuxers,parsers,doc,swscale,postproc,network} \
                --disable-{avdevice,autodetect} \
                --disable-bsfs --enable-protocol=file,data \
                --enable-encoder=flac,tta,aac,wavpack,alac,pcm_s16le,pcm_s32le \
                --enable-muxer=flac,tta,ipod,wv,mp3,opus,ogg,wav,pcm_s16le,pcm_s32le,image2,singlejpeg \
                --enable-parser=png,mjpeg --enable-decoder=mjpeg,png \
                --enable-demuxer=image2,singlejpeg \
                --enable-{bzlib,zlib,lzma,iconv} \
                --enable-filter=hdcd \
                "${cyan_ffmpeg_opts[@]}"
            do_makeinstall
            files_exist "${_check[@]}" && touch ../"build_successful${bits}_cyan"
        fi
        unset cyan_ffmpeg_opts
        PKG_CONFIG_PATH=$LOCALDESTDIR/opt/cyanffmpeg/lib/pkgconfig:$PKG_CONFIG_PATH

        cd_safe "$LOCALBUILDDIR"/cyanrip-git
        _check=(bin-audio/cyanrip.exe)
        _extra_cflags=("$(cygpath -m "$LOCALDESTDIR/opt/cyanffmpeg/include")"
            "$(cygpath -m "$LOCALDESTDIR/include")")
        _extra_ldflags=("$(cygpath -m "$LOCALDESTDIR/opt/cyanffmpeg/lib")"
            "$(cygpath -m "$LOCALDESTDIR/lib")")
        hide_conflicting_libs "$LOCALDESTDIR/opt/cyanffmpeg"
        CFLAGS+=" -DLIBXML_STATIC $(printf ' -I%s' "${_extra_cflags[@]}")" \
        LDFLAGS+="$(printf ' -L%s' "${_extra_ldflags[@]}")" \
            do_mesoninstall audio
        hide_conflicting_libs -R "$LOCALDESTDIR/opt/cyanffmpeg"
        do_checkIfExist
        PKG_CONFIG_PATH=$old_PKG_CONFIG_PATH
        unset old_PKG_CONFIG_PATH _extra_ldflags _extra_cflags
    fi
fi

if [[ $vlc == y ]]; then
    do_pacman_install lib{cddb,nfs,shout,samplerate,microdns,secret} \
        a52dec taglib gtk3 lua perl

    # Remove useless shell scripts file that causes errors when stdout is not a tty.
    find "$MINGW_PREFIX/bin/" -name "luac" -delete

    _check=("$DXSDK_DIR/fxc2.exe" "$DXSDK_DIR/d3dcompiler_47.dll")
    if do_vcs "https://github.com/mozilla/fxc2.git"; then
        do_uninstall "${_check[@]}"
        do_patch "https://code.videolan.org/videolan/vlc/-/raw/master/contrib/src/fxc2/0001-make-Vn-argument-as-optional-and-provide-default-var.patch" am
        do_patch "https://code.videolan.org/videolan/vlc/-/raw/master/contrib/src/fxc2/0002-accept-windows-style-flags-and-splitted-argument-val.patch" am
        do_patch "https://code.videolan.org/videolan/vlc/-/raw/master/contrib/src/fxc2/0004-Revert-Fix-narrowing-conversion-from-int-to-BYTE.patch" am
        $CXX $CFLAGS -static -static-libgcc -static-libstdc++ -o "$DXSDK_DIR/fxc2.exe" fxc2.cpp -ld3dcompiler $LDFLAGS
        case $bits in
        32*) cp -f "dll/d3dcompiler_47_32.dll" "$DXSDK_DIR/d3dcompiler_47.dll" ;;
        *) cp -f "dll/d3dcompiler_47.dll" "$DXSDK_DIR/d3dcompiler_47.dll" ;;
        esac
        do_checkIfExist
    fi

    # Taken from https://code.videolan.org/videolan/vlc/blob/master/contrib/src/qt/AddStaticLink.sh
    _add_static_link() {
        local PRL_SOURCE=$LOCALDESTDIR/$2/lib$3.prl LIBS
        [[ -f $PRL_SOURCE ]] || PRL_SOURCE=$LOCALDESTDIR/$2/$3.prl
        [[ ! -f $PRL_SOURCE ]] && return 1
        LIBS=$(sed -e "
            /QMAKE_PRL_LIBS =/ {
                s@QMAKE_PRL_LIBS =@@
                s@$LOCALDESTDIR/lib@\${libdir}@g
                s@\$\$\[QT_INSTALL_LIBS\]@\${libdir}@g
                p
            }
            d" "$PRL_SOURCE" | grep -v QMAKE_PRL_LIBS_FOR_CMAKE)
        sed -i.bak "
            s# -l$1# -l$3 -l$1#
            s#Libs.private:.*#& $LIBS -L\${prefix}/$2#
            " "$LOCALDESTDIR/lib/pkgconfig/$1.pc"
    }

    _qt_version=5.15 # Version that vlc uses
    # $PKG_CONFIG --exists Qt5{Core,Widgets,Gui,Quick{,Widgets,Controls2},Svg}

    # Qt compilation takes ages.
    export QMAKE_CXX=$CXX QMAKE_CC=$CC
    export MSYS2_ARG_CONV_EXCL="--foreign-types="
    _check=(bin/qmake.exe Qt5Core.pc Qt5Gui.pc Qt5Widgets.pc)
    if do_vcs "https://github.com/qt/qtbase.git#branch=${_qt_version:=5.15}"; then
        do_uninstall include/QtCore share/mkspecs "${_check[@]}"
        # Enable ccache on !unix and use cygpath to fix certain issues
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/qtbase/0001-qtbase-mabs.patch" am
        do_patch "https://code.videolan.org/videolan/vlc/-/raw/master/contrib/src/qt/0003-allow-cross-compilation-of-angle-with-wine.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/qtbase/0003-Remove-wine-prefix-before-fxc2.patch" am
        do_patch "https://code.videolan.org/videolan/vlc/-/raw/master/contrib/src/qt/0006-ANGLE-don-t-use-msvc-intrinsics-when-crosscompiling-.patch" am
        do_patch "https://code.videolan.org/videolan/vlc/-/raw/master/contrib/src/qt/0009-Add-KHRONOS_STATIC-to-allow-static-linking-on-Windows.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/qtbase/0006-qt_module.prf-don-t-create-libtool-if-not-unix.patch" am
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/qtbase/0007-qmake-Patch-win32-g-for-static-builds.patch" am
        cp -f src/3rdparty/angle/src/libANGLE/{,libANGLE}Debug.cpp
        grep_and_sed "src/libANGLE/Debug.cpp" src/angle/src/common/gles_common.pri \
            "s#src/libANGLE/Debug.cpp#src/libANGLE/libANGLEDebug.cpp#g"

        QT5Base_config=(
            -prefix "$LOCALDESTDIR"
            -datadir "$LOCALDESTDIR"
            -archdatadir "$LOCALDESTDIR"
            -opensource
            -confirm-license
            -release
            -static
            -platform "$(
                case $CC in
                *clang) echo win32-clang-g++ ;;
                *) echo win32-g++ ;;
                esac
            )"
            -make-tool make
            -qt-{libjpeg,freetype,zlib}
            -angle
            -no-{shared,fontconfig,pkg-config,sql-sqlite,gif,openssl,dbus,vulkan,sql-odbc,pch,compile-examples,glib,direct2d,feature-testlib}
            -skip qtsql
            -nomake examples
            -nomake tests
        )
        if [[ $strip == y ]]; then
            QT5Base_config+=(-strip)
        fi
        if [[ $ccache == y ]]; then
            QT5Base_config+=(-ccache)
        fi
        # can't use regular do_configure since their configure doesn't follow
        # standard and uses single dash args
        log "configure" ./configure "${QT5Base_config[@]}"

        do_make
        do_makeinstall

        _add_static_link Qt5Gui plugins/imageformats qjpeg
        grep_or_sed "QtGui/$(qmake -query QT_VERSION)/QtGui" "$LOCALDESTDIR/lib/pkgconfig/Qt5Gui.pc" \
            "s;Cflags:.*;& -I\${includedir}/QtGui/$(qmake -query QT_VERSION)/QtGui;"
        _add_static_link Qt5Gui plugins/platforms qwindows
        _add_static_link Qt5Widgets plugins/styles qwindowsvistastyle

        cat >> "$LOCALDESTDIR/mkspecs/win32-g++/qmake.conf" <<'EOF'
CONFIG += static
EOF
        do_checkIfExist
    fi

    _deps=(Qt5Core.pc)
    _check=(Qt5Quick.pc Qt5Qml.pc)
    if do_vcs "https://github.com/qt/qtdeclarative.git#branch=$_qt_version"; then
        do_uninstall "${_check[@]}"
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/qtdeclarative/0001-features-hlsl_bytecode_header.prf-Use-DXSDK_DIR-for-.patch" am
        git cherry-pick 0b9fcb829313d0eaf2b496bf3ad44e5628fa43b2 > /dev/null 2>&1 ||
            git cherry-pick --abort
        do_qmake
        do_makeinstall
        _add_static_link Qt5Quick qml/QtQuick.2 qtquick2plugin
        _add_static_link Qt5Quick qml/QtQuick/Layouts qquicklayoutsplugin
        _add_static_link Qt5Quick qml/QtQuick/Window.2 windowplugin
        _add_static_link Qt5Qml qml/QtQml/Models.2 modelsplugin
        do_checkIfExist
    fi

    _deps=(Qt5Core.pc)
    _check=(Qt5Svg.pc)
    if do_vcs "https://github.com/qt/qtsvg.git#branch=$_qt_version"; then
        do_uninstall "${_check[@]}"
        do_qmake
        do_makeinstall
        _add_static_link Qt5Svg plugins/iconengines qsvgicon
        _add_static_link Qt5Svg plugins/imageformats qsvg
        do_checkIfExist
    fi

    _deps=(Qt5Core.pc Qt5Quick.pc Qt5Qml.pc)
    _check=("$LOCALDESTDIR/qml/QtGraphicalEffects/libqtgraphicaleffectsplugin.a")
    if do_vcs "https://github.com/qt/qtgraphicaleffects.git#branch=$_qt_version"; then
        do_uninstall "${_check[@]}"
        do_qmake
        do_makeinstall
        _add_static_link Qt5QuickWidgets qml/QtGraphicalEffects qtgraphicaleffectsplugin
	    _add_static_link Qt5QuickWidgets qml/QtGraphicalEffects/private qtgraphicaleffectsprivate
        do_checkIfExist
    fi

    _deps=(Qt5Core.pc Qt5Quick.pc Qt5Qml.pc)
    _check=(Qt5QuickControls2.pc)
    if do_vcs "https://github.com/qt/qtquickcontrols2.git#branch=$_qt_version"; then
        do_uninstall "${_check[@]}"
        do_qmake
        do_makeinstall
        _add_static_link Qt5QuickControls2 qml/QtQuick/Controls.2 qtquickcontrols2plugin
        _add_static_link Qt5QuickControls2 qml/QtQuick/Templates.2 qtquicktemplates2plugin
        do_checkIfExist
    fi

    _check=(libspatialaudio.a spatialaudio/Ambisonics.h spatialaudio.pc)
    if do_vcs "https://github.com/videolabs/libspatialaudio.git"; then
        do_uninstall include/spatialaudio "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi

    _check=(libshout.{,l}a shout.pc shout/shout.h)
    if do_vcs "https://gitlab.xiph.org/xiph/icecast-libshout.git" libshout; then
        do_uninstall "${_check[@]}"
        log -q "git.submodule" git submodule update --init
        do_autoreconf
        CFLAGS+=" -include ws2tcpip.h" do_separate_confmakeinstall --disable-examples LIBS="$($PKG_CONFIG --libs openssl)"
        do_checkIfExist
    fi

    _check=(bin/protoc.exe libprotobuf-lite.{,l}a libprotobuf.{,l}a protobuf{,-lite}.pc)
    if do_vcs "https://github.com/protocolbuffers/protobuf.git"; then
        do_uninstall include/google/protobuf "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall
        do_checkIfExist
    fi

    _check=(pixman-1.pc libpixman-1.a pixman-1/pixman.h)
    if do_vcs "https://gitlab.freedesktop.org/pixman/pixman.git"; then
        do_uninstall include/pixman-1 "${_check[@]}"
        do_patch "https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/pixman/0001-pixman-pixman-mmx-fix-redefinition-of-_mm_mulhi_pu16.patch" am
        NOCONFIGURE=y do_autogen
        CFLAGS="-msse2 -mfpmath=sse -mstackrealign $CFLAGS" \
            do_separate_confmakeinstall
        do_checkIfExist
    fi

    _check=(libmedialibrary.a medialibrary.pc medialibrary/IAlbum.h)
    if do_vcs "https://code.videolan.org/videolan/medialibrary.git"; then
        do_uninstall include/medialibrary "${_check[@]}"
        do_mesoninstall -Dtests=disabled -Dlibvlc=disabled
        do_checkIfExist
    fi

    _check=(libthai.pc libthai.{,l}a thai/thailib.h)
    if do_vcs "https://github.com/tlwg/libthai.git"; then
        do_uninstall include/thai "${_check[@]}"
        do_autogen
        do_separate_confmakeinstall
        do_checkIfExist
    fi

    _check=(libebml.a ebml/ebml_export.h libebml.pc lib/cmake/EBML/EBMLTargets.cmake)
    if do_vcs "https://github.com/Matroska-Org/libebml.git"; then
        do_uninstall include/ebml lib/cmake/EBML "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi

    _check=(libmatroska.a libmatroska.pc matroska/KaxTypes.h lib/cmake/Matroska/MatroskaTargets.cmake)
    if do_vcs "https://github.com/Matroska-Org/libmatroska.git"; then
        do_uninstall include/matroska lib/cmake/Matroska "${_check[@]}"
        do_cmakeinstall
        do_checkIfExist
    fi

    _check=("$LOCALDESTDIR"/vlc/bin/{{c,r}vlc,vlc.exe,libvlc.dll}
            "$LOCALDESTDIR"/vlc/libexec/vlc/vlc-cache-gen.exe
            "$LOCALDESTDIR"/vlc/lib/pkgconfig/libvlc.pc
            "$LOCALDESTDIR"/vlc/include/vlc/libvlc_version.h)
    if do_vcs "https://code.videolan.org/videolan/vlc.git"; then
        do_uninstall bin/plugins lib/vlc "${_check[@]}"
        _mabs_vlc=https://raw.githubusercontent.com/m-ab-s/mabs-patches/master/vlc
        do_patch "https://code.videolan.org/videolan/vlc/-/merge_requests/155.patch" am
        do_patch "$_mabs_vlc/0001-modules-access-srt-Use-srt_create_socket-instead-of-.patch" am
        do_patch "$_mabs_vlc/0002-modules-codec-libass-Use-ass_set_pixel_aspect-instea.patch" am
        do_patch "$_mabs_vlc/0003-Use-libdir-for-plugins-on-msys2.patch" am
        do_patch "$_mabs_vlc/0004-include-vlc_fixups.h-fix-iovec-is-redefined-errors.patch" am
        do_patch "$_mabs_vlc/0005-include-vlc_common.h-fix-snprintf-and-vsnprintf-rede.patch" am
        do_patch "$_mabs_vlc/0006-configure.ac-check-if-_WIN32_IE-is-already-defined.patch" am
        do_patch "$_mabs_vlc/0007-modules-stream_out-rtp-don-t-redefine-E-defines.patch" am
        do_patch "$_mabs_vlc/0008-include-vlc_codecs.h-don-t-redefine-WAVE_FORMAT_PCM.patch" am
        do_patch "$_mabs_vlc/0009-modules-audio_filter-channel_mixer-spatialaudio-add-.patch" am
        do_patch "$_mabs_vlc/0010-modules-access_output-don-t-put-lgpg-error-for-liveh.patch" am

        do_autoreconf
        # All of the disabled are because of multiple issues both on the installed libs and on vlc's side.
        # Maybe set up vlc_options.txt

        # Can't disable shared since vlc will error out. I don't think enabling static will really do anything for us other than breaking builds.
        create_build_dir
        config_path=".." do_configure \
            --prefix="$LOCALDESTDIR/vlc" \
            --sysconfdir="$LOCALDESTDIR/vlc/etc" \
            --{build,host,target}="$MINGW_CHOST" \
            --enable-{shared,avcodec,merge-ffmpeg,qt,nls} \
            --disable-{static,dbus,fluidsynth,svgdec,aom,mod,ncurses,mpg123,notify,svg,secret,telx,ssp,lua,gst-decode,nvdec} \
            --with-binary-version="MABS" BUILDCC="$CC" \
            CFLAGS="$CFLAGS -DGLIB_STATIC_COMPILATION -DQT_STATIC -DGNUTLS_INTERNAL_BUILD -DLIBXML_STATIC -DLIBXML_CATALOG_ENABLED" \
            LIBS="$($PKG_CONFIG --libs libcddb regex iconv) -lwsock32 -lws2_32 -lpthread -liphlpapi"
        do_makeinstall
        do_checkIfExist
        PATH="$LOCALDESTDIR/vlc/bin:$PATH" "$LOCALDESTDIR/vlc/libexec/vlc/vlc-cache-gen" "$LOCALDESTDIR/vlc/lib/plugins"
    fi
fi

_check=(bin-video/ffmbc.exe)
if [[ $ffmbc = y ]] && do_vcs "https://github.com/bcoudurier/FFmbc.git#branch=ffmbc"; then # no other branch
    _notrequired=true
    create_build_dir
    log configure ../configure --target-os=mingw32 --enable-gpl \
        --disable-{dxva2,ffprobe} --extra-cflags=-DNO_DSHOW_STRSAFE \
        --cc="$CC" --ld="$CXX"
    do_make
    do_install ffmbc.exe bin-video/
    do_checkIfExist
    unset _notrequired
fi

do_simple_print -p "${orange}Finished $bits compilation of all tools${reset}"
}

run_builds() {
    new_updates=no
    new_updates_packages=""
    if [[ $build32 = yes ]]; then
        source /local32/etc/profile2.local
        buildProcess
    fi

    if [[ $build64 = yes ]]; then
        source /local64/etc/profile2.local
        buildProcess
    fi
}

cd_safe "$LOCALBUILDDIR"
run_builds

while [[ $new_updates = yes ]]; do
    ret=no
    printf '%s\n' \
        "-------------------------------------------------------------------------------" \
        "There were new updates while compiling." \
        "Updated:$new_updates_packages" \
        "Would you like to run compilation again to get those updates? Default: no"
    do_prompt "y/[n] "
    echo "-------------------------------------------------------------------------------"
    if [[ $ret = y || $ret = Y || $ret = yes ]]; then
        run_builds
    else
        break
    fi
done

clean_suite
if [[ -f $LOCALBUILDDIR/post_suite.sh ]]; then
    do_simple_print -p "${green}Executing post_suite.sh${reset}"
    source "$LOCALBUILDDIR"/post_suite.sh || true
fi
do_simple_print -p "${green}Compilation successful.${reset}"
do_simple_print -p "${green}This window will close automatically in 5 seconds.${reset}"
sleep 5
