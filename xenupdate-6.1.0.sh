#!/bin/bash
# {{{ DEFINE
i=0
let p=0
let n=0
# Xenserver version
VERSION='6.1.0'

# Update PATCH file URL
URL='http://<update server>/Xenserver'
# program
AWK="/bin/awk"
CAT="/bin/cat"
GREP="/bin/grep"
RM="/bin/rm -f"
WGET="/usr/bin/wget -q"
XE="/opt/xensource/bin/xe"
# }}}

# {{{ PATCH LISTS
# Enable PATCH
PATCH=(
XS61E001
XS61E003
XS61E004
XS61E006
XS61E009
XS61E010
)

PATCH_UUID=(
#XS61E001
7fd1ba20-1582-4b02-a61d-c251ad0b637c
#XS61E003
c5354c77-4643-4e79-8cdf-fac914fc6c85
#XS61E004
82e98b1f-e547-4461-aea0-6b3cfd28780f
#XS61E006
618b244c-7d58-4c26-b0f1-d870134de13e
#XS61E009
ff5a3ea3-b3dc-41ec-8a6e-9b47270e544a
#XS61E010
193ed7db-c46b-4655-a708-2332534cebc9
)

PATCH_EXCLUDES=(
XS61E002
XS61E005
XS61E008
)
# }}}

cd /root/
BEGIN_TIME=`date '+%Y-%d-%M %H:%I:%m:%S'`
echo "[BEGIN] ${BEGIN_TIME} ${HOSTNAME}"

# {{{ CHECK Xenserver version
if [ ! -f ${XE} ]; then
	echo "[ERROR] Only Xenserver"
	exit 1
else
	if `${CAT} /etc/redhat-release | ${GREP} "${VERSION}" 1>/dev/null 2>&1` ; then
		echo "[VERSION] ${VERSION} OK"
	else
		echo "[ERROR] Xenserver ${VERSION} version does not match server"
		exit 1
	fi
fi
# }}} 

# {{{ CHECK PATCH LISTS

# CURRENT PATCH LISTS
PATCH_ENABLED=`${XE} patch-list | ${GREP} "name-label" | ${AWK} '{print $4}' | sort`

#echo ${PATCH_ENABLED}
# PATCH EXCLUDES PROCESS
if [ ! "${#PATCH_EXCLUDES[@]}" == "0" ]; then
	for e in ${PATCH_EXCLUDES[@]}
	do
		PATCH_ENABLED=${PATCH_ENABLED/$e}
	done
fi

#Deduplication PATCH
if [ ! "${PATCH_ENABLED}" == "" ]; then
	let p=0
	for cur in ${PATCH_ENABLED}
	do
		for new in ${PATCH[@]}
		do
			if [ "${new}" == "${cur}" ]; then
				unset -v 'PATCH[p]'
				unset -v 'PATCH_UUID[p]'
			fi
			new=''
		done

		let p=${p}+1
	done
fi

#Recreation PATCH UUID
PUUID=(${PATCH_UUID[@]})

if [ "${#PATCH[@]}" == "0" ]; then
	echo "[WARN] No longer PATCHES"
fi
# }}}

# {{{ GET Xenserver HOST UUID
UUID=`${XE} host-list | ${GREP} uuid | ${AWK} '{print $5}'`
if [ "${UUID}" == "" ]; then 
	echo "[ERROR] Failure Xenserver HOST UUID collected"
	exit 1
else
	echo "[HOST UUID] ${UUID}"
fi
# }}}

# {{{ DOWNLOAD Xenserver PATCHES
let n=0
for i in ${PATCH[@]}
do
	let n=${n}+1
	echo "[DOWN ${n}] ${URL}/${i}.xsupdate"
	#echo "${WGET}  ${URL}/${i}.xsupdate 1>/dev/null 2>&1"
	${WGET}  ${URL}/${i}.xsupdate 1>/dev/null 2>&1
done
# }}}

# {{{ APPLY Xenserver PATCHES
let p=0
let n=0
for i in ${PATCH[@]}
do
	let n=${n}+1
	if [ -f ./${i}.xsupdate ]; then
		echo "[APPLY ${n}] ${i}"
		chk=`${XE} patch-upload file-name=./${i}.xsupdate | awk '{print $2}'`
		echo ${chk}
		##PUUID=$(eval "echo \${$(echo PUUID_${p})}")
		#echo "${XE} patch-apply uuid=${PUUID[${p}]} host-uuid=${UUID}"
		${XE} patch-apply uuid=${PUUID[${p}]} host-uuid=${UUID}
	else
		echo "[APPLY WARN] No files(${i}.xsupdate)"
	fi

	let p=$p+1
done
# }}}

# {{{ DELETE Xenserver PATCHES
let n=0
for i in ${PATCH[@]}
do
	let n=${n}+1
	echo "[DELETE ${n}] ${i}.xsupdate"
	if [ -f ./${i}.xsupdate ];then
		#echo "${RM} ./${i}.xsupdate"
		${RM} ./${i}.xsupdate
	else
		echo "[DELETE WARN] No files(${i}.xsupdate)"
	fi
done
# }}}

# {{{ PATCHED LISTS
echo "[PATCHED LISTS]"
${XE} patch-list | ${GREP} "name-label" | ${AWK} '{print $4}' | sort
# }}}

END_TIME=`date '+%Y-%d-%M %H:%I:%m:%S'`
echo "[END] ${END_TIME} ${HOSTNAME}"


exit 0
