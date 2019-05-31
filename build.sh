#!/bin/bash

# This script prepare Core, all existed adapters and fat framework
# for testing and production


# Environment variables
export BUILD_NAME=""
export VERSION=""
export PROJECT_DIR=$(PWD)
export SHOULD_UPDATE_PODS="NO"
export SHOULD_COMPRESS_RESULTS="YES"
export WITHOUT_ADAPTERS="NO"
export SHOULD_UPLOAD_TO_S3="YES"
export RELEASE_DIR=$PROJECT_DIR/Release
export TEMP_DIR=$PROJECT_DIR/build

export COMPONENTS=(
    "BidMachine.framework/BidMachine"
    "DisplayKit.framework/DisplayKit"
    "libBDMMRAIDAdapter.a"
    "libBDMNASTAdapter.a"
    "libBDMVASTAdapter.a"
    "NexageSourceKitMRAID.framework/NexageSourceKitMRAID"
    "Protobuf.framework/Protobuf"
)

export PODS_DEPS=(
    "AppodealDocumentParser"
    "AppodealNASTKit"
    "ASKProductPresentation"
    "ASKSpinner"
    "ASKLogger"
    "ASKDiskUtils"
    "ASKViewabilityTracker"
    "ASKExtension"
)

# Utility 
export ERROR='\033[0;31m'   # Red color
export INFO='\033[0m'       # Standart color
export WARNING='\033[0;33m' # Orange color

# Functions
function build_mangled_binary {
    local scheme_id=$1
    local sdk_id=$2
    local output=$3

    touch "$output/$scheme_id-$sdk_id-build.log"
    # STRIP_INSTALLED_PRODUCT, DEPLOYMENT_POSTPROCESSING            - clear warnings of .pcm files
    # LINK_FRAMEWORKS_AUTOMATICALLY                                 - supports for -all_load CF flag
    # CLANG_DEBUG_INFORMATION_LEVEL, GCC_GENERATE_DEBUGGING_SYMBOLS - reduce binary size
    # OTHER_CFLAGS                                                  - enables bitcode
    # IPHONEOS_DEPLOYMENT_TARGET                                    - set min support version
    # MACH_O_TYPE                                                   - only static frameworks
    # GCC_PREPROCESSOR_DEFINITIONS                                  - set Protobuf imports as framework
    xcodebuild  -workspace "$PROJECT_DIR/BidMachine.xcworkspace" \
                -scheme "$scheme_id" \
                -sdk "$sdk_id" \
                -configuration Release \
                STRIP_INSTALLED_PRODUCT=YES \
                LINK_FRAMEWORKS_AUTOMATICALLY=NO \
                CLANG_DEBUG_INFORMATION_LEVEL="-gline-tables-only" \
                OTHER_CFLAGS="-fembed-bitcode -Qunused-arguments" \
                IPHONEOS_DEPLOYMENT_TARGET=9.0 \
                MACH_O_TYPE=staticlib \
                DEPLOYMENT_POSTPROCESSING=YES \
                GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
                build \
                CONFIGURATION_BUILD_DIR="$output" > "$output/$scheme_id-$sdk_id-build.log"
}

function rebuild_components {
    local simulator_temp_dir=$TEMP_DIR/iphonesimulator
    local device_temp_dir=$TEMP_DIR/iphoneos
    local universal_temp_dir=$TEMP_DIR/universal

    echo -e "${INFO}Build components by scheme BidMachine${INFO}"
    echo -e "${INFO}All logs in build/build type/build.log${INFO}"

    # Clear temporary build directories
    mkdir -p $simulator_temp_dir
    mkdir -p $device_temp_dir
    mkdir -p $universal_temp_dir

    local scheme="BidMachine" 
    # Build for all archs (i386, x86-64), (armv7, armv7s)
    build_mangled_binary "$scheme" iphonesimulator "$simulator_temp_dir"
    build_mangled_binary "$scheme" iphoneos "$device_temp_dir"

    find $device_temp_dir -type d -iname "*.framework" -exec cp -r {} $universal_temp_dir \;
    cp -r $device_temp_dir/BidMachine.framework $universal_temp_dir

    echo -e "${INFO}Create universal static binaries ${COMPONENTS[@]}${INFO}"

    for component in ${COMPONENTS[@]}; do
      lipo -create "$device_temp_dir/$component" "$simulator_temp_dir/$component" -output "$universal_temp_dir/$component"
    done
}

function merge_components {
    local universal_temp_dir=$TEMP_DIR/universal
    local components_paths=()
    local dependencies_paths=()

    echo -e "${INFO}Search components...${INFO}"

    for component in ${COMPONENTS[@]}; do
      if [[ -f $universal_temp_dir/$component ]]; then
        components_paths+=( $universal_temp_dir/$component )
      fi
    done

    for dependency in ${PODS_DEPS[@]}; do
        dependencies_paths+=( $(find "$PROJECT_DIR/Pods" -type f -iname $dependency) )
    done

    libtool -static -o "$universal_temp_dir/BidMachine.framework/BidMachine" "${components_paths[@]}" "${dependencies_paths[@]}"
    mv "$universal_temp_dir/BidMachine.framework" "$RELEASE_DIR/BidMachine.framework"
}

function compress_and_upload {
  cd $RELEASE_DIR
  [ "$SHOULD_COMPRESS_RESULTS" = "YES" ] &&  zip -r "$BUILD_NAME.zip" * > /dev/null
  [ "$SHOULD_UPLOAD_TO_S3" = "YES" ] && aws s3 cp "$(PWD)/$BUILD_NAME.zip" "s3://appodeal-ios/BidMachine/$VERSION/$BUILD_NAME.zip" --acl public-read
}


# Console IO
while test $# -gt 0; do
        case "$1" in
                -h|--help)
                        echo -e "$package - attempt to capture frames"
                        echo -e " "
                        echo -e "$package [options] application [arguments]"
                        echo -e " "
                        echo -e "options:"
                        echo -e "-h, --help                                       show brief help"
                        echo -e "-v, --version                                    specify version of build. ${WARNING}Required${INFO}"
                    #  Currently no supported
                    #  echo -e "-wo, -without_adapters=YES                       remove adapters, by default is NO ${WARNING}Optional${INFO}"            
                        echo -e "-pu, --pod_update=YES                            update CocoaPods Environment. ${WARNING}Optional${INFO}" 
                        echo -e "-s3, --s3_upload=YES                             upload results to Amazon s3. ${WARNING}Optional${INFO}"
                        echo -e "-z, --zip=YES                                    compress results. ${WARNING}Optional${INFO}"
                        exit 0
                        ;;
                -wo)
                        shift
                        if test $# -gt 0; then
                                WITHOUT_ADAPTERS=$1
                        else
                                echo -e "${ERROR} ❌ wo flag should have value YES or NO specified${INFO}"
                                exit 1
                        fi
                        shift
                        ;;
                --without_adapters*)
                        export WITHOUT_ADAPTERS=`echo -e $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;        
                -v)
                        shift
                        if test $# -gt 0; then
                                VERSION=$1
                                BUILD_NAME="BidMachine-SDK-iOS-$VERSION" 
                        else
                                echo -e "${ERROR} ❌ No version specified${INFO}"
                                exit 1
                        fi
                        shift
                        ;;
                --version*)
                                VERSION=`echo -e $1 | sed -e 's/^[^=]*=//g'`
                                BUILD_NAME="Appodeal-SDK-iOS-$VERSION" 
                        shift
                        ;;        
                -pu)
                        shift
                        if test $# -gt 0; then
                                SHOULD_UPDATE_PODS=$1
                        else
                                echo -e "${ERROR} ❌ No CocoaPods flag specified${INFO}"
                                exit 1
                        fi
                        shift
                        ;;
                --pod_update*)
                        export SHOULD_UPDATE_PODS=`echo -e $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                -s3)
                        shift
                        if test $# -gt 0; then
                                SHOULD_UPLOAD_TO_S3=$1
                        else
                                echo -e "${ERROR} ❌ No s3 upload specified${INFO}"
                                exit 1
                        fi
                        shift
                        ;;
                --s3_upload*)
                        export SHOULD_UPLOAD_TO_S3=`echo -e $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                -z)
                        shift
                        if test $# -gt 0; then
                                SHOULD_COMPRESS_RESULTS=$1
                        else
                                echo -e "${ERROR} ❌ No zip compress specified${INFO}"
                                exit 1
                        fi
                        shift
                        ;;
                --zip*)
                        export SHOULD_COMPRESS_RESULTS=`echo -e $1 | sed -e 's/^[^=]*=//g'`
                        shift
                        ;;
                *)
                        break
                        ;;
        esac
done

start=`date +%s`
# Evaluation 
if [[ $BUILD_NAME == "" ]];then
  echo -e "${ERROR} ❌ No build version specified!"
  exit 1
fi

# Clear release dir
rm -rf $RELEASE_DIR
mkdir -p $RELEASE_DIR

rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

echo -e "🔨 Build configuration:"
echo -e "Build name:        ${WARNING}${BUILD_NAME}${INFO}"
echo -e "Update CocoaPods:  ${WARNING}${SHOULD_UPDATE_PODS}${INFO}"
echo -e "Core only:         ${WARNING}${WITHOUT_ADAPTERS}${INFO}"
echo -e "ZIP:               ${WARNING}$SHOULD_COMPRESS_RESULTS${INFO}"
echo -e "S3 upload:         ${WARNING}$SHOULD_UPLOAD_TO_S3${INFO}"

[ "$SHOULD_UPDATE_PODS" = "YES" ] && pod update

echo -e "${WARNING}🔨 Build release framework modules${INFO}"
rebuild_components
echo -e "${WARNING}📦 Link statically release framework modules${INFO}"
merge_components
echo -e "${WARNING}🚀 Compress and upload results${INFO}"
compress_and_upload
end=`date +%s`
runtime=$((end-start))
echo -e "${INFO}🔥 Distribution finished at: $runtime seconds${INFO}"