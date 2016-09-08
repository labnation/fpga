#!/bin/bash 
#Quit script when command fails
set -e 

BINDIR=$XILINX_BIN_DIR
if [ "${MSYSTEM:0:5}" = "MINGW" ] 
then
	BUILD_DIR=`pwd`/$(dirname $0)
	echo Building on windows - build dir = $BUILD_DIR
else
	BUILD_DIR=$(dirname $0)
	echo Building on UNIX - build dir = $BUILD_DIR
fi
BITSTREAM_DIR=$BUILD_DIR/../bitstreams
WORK_DIR=$BUILD_DIR/../work_script
IPCORE_DIR=$BUILD_DIR/../ipcore_dir
REPORTS_DIR=$BUILD_DIR/reports

BUILD_DATE=`date +%Y-%m-%d_%Hh%M`
VERSION=`git rev-parse HEAD`
BUILD_VERSION_HDL=$WORK_DIR/BuildVersion.vhd

BASENAME=SmartScopeHackerSpecial
LOG_FILE=$REPORTS_DIR/${BASENAME}_$BUILD_DATE
PARTNAME=xc6slx4-tqg144-3

mkdir -p $REPORTS_DIR

XST=$BINDIR/xst
NGD=$BINDIR/ngdbuild
MAP=$BINDIR/map
PAR=$BINDIR/par
TRCE=$BINDIR/trce
BITGEN=$BINDIR/bitgen
COREGEN=$BINDIR/coregen

XST_OPTIONS=$BUILD_DIR/synthesis_options.txt
XST_FILELIST=$BUILD_DIR/hdl_files.txt
XST_REPORT=$REPORT_DIR/synthesis.txt
CONSTRAINTS=$BUILD_DIR/../constraints/${BASENAME}.ucf
BITSTREAM_OPTIONS=$BUILD_DIR/bitstream_options.txt

##########################################
### PREPARE WORK DIR
echo Cleaning out working directory \($WORK_DIR\)
rm -rf $WORK_DIR || true
mkdir -p $WORK_DIR
cd $WORK_DIR

##########################################
### Generate IP (if requested)
if [[ $2 = 'regenerate_ip' ]]; then
    cd $IPCORE_DIR
    for i in *.xco; do
        echo === Regenerating code ${i} ====
        ${COREGEN} -p ${PARTNAME}.cgp -b ${i} -r -intstyle xflow
        echo === Done regenerating code ${i} ====
    done
    cd $WORK_DIR
fi

##########################################
### Generate build nr HDL file

echo "
library IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
package BuildVersion is
constant BUILD_VERSION	:	UNSIGNED(31 DOWNTO 0) := x\"${VERSION:0:8}\"; -- Git ref hash
end BuildVersion;" > $BUILD_VERSION_HDL

##########################################
### SYNTHESIS
echo Synthesis \(1/6\)

cp $XST_FILELIST ./
$XST -intstyle xflow -ifn $XST_OPTIONS -ofn ${BASENAME}.srp
cp ${BASENAME}.srp $LOG_FILE.srp

##########################################
### TRANSLATE
echo Translate \(2/6\)
$NGD -intstyle xflow -dd _ngo -sd $IPCORE_DIR -nt on -uc $CONSTRAINTS -p $PARTNAME $BASENAME.ngc $BASENAME.ngd
cp ${BASENAME}.bld $LOG_FILE.bld

##########################################
### MAP (uses ${BASENAME}_map.ngd - creates ${BASENAME}_map.ncd  - PCF file is Physical Constraints File)
echo Map \(3/6\)
$MAP -intstyle xflow -detail -p $PARTNAME \
		-w -logic_opt off -ol high -xe n -t 1 -xt 0 -r 4 -global_opt area \
		-equivalent_register_removal on -mt 2 -ir off -ignore_keep_hierarchy \
		-pr off -lc auto -power off \
		-o ${BASENAME}_map.ncd ${BASENAME}.ngd ${BASENAME}.pcf
		
cp ${BASENAME}_map.mrp $LOG_FILE.mrp

##########################################
### PLACE AND ROUTE (uses ${BASENAME}_map.ncd - creates ${BASENAME}.ncd - PCF file is Physical Constraints File)
echo Place \& Route \(4/6\)
$PAR -w -intstyle xflow -ol high -power on ${BASENAME}_map.ncd ${BASENAME}.ncd ${BASENAME}.pcf	
cp ${BASENAME}.par $LOG_FILE.par

##########################################
### TRACE
echo Trace \(5/6\)
$TRCE -intstyle xflow -v 3 -s 3 -n 3 -fastpaths -xml ${BASENAME}.twx ${BASENAME}.ncd -o ${BASENAME}.twr ${BASENAME}.pcf
cp ${BASENAME}.twr $LOG_FILE.twr
cp ${BASENAME}.twx $LOG_FILE.twx

##########################################
### Bitgen
echo Bitgen \(6/6\)
$BITGEN -intstyle xflow -f ${BITSTREAM_OPTIONS} ${BASENAME}.ncd 
cp ${BASENAME}.bgn $LOG_FILE.bgn

##########################################
### Save XMSGs for easy viewing of warnings
cp -r _xmsgs ${LOG_FILE}_xmsgs

##########################################
### Save bitstreams
echo Copying bitstreams to bitstream dir
mkdir -p ${BITSTREAM_DIR}
cp ${BASENAME}.bit ${BITSTREAM_DIR}/${BASENAME}_${VERSION}.bit
cp ${BASENAME}.bin ${BITSTREAM_DIR}/${BASENAME}_${VERSION}.bin
cp ${BASENAME}.bit ${BITSTREAM_DIR}/${BASENAME}.bit
cp ${BASENAME}.bin ${BITSTREAM_DIR}/${BASENAME}.bin

echo
echo
echo ===== BUILD DONE = VERSION USED : $VERSION =====
