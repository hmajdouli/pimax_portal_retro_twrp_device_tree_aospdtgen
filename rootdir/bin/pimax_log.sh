#!/system/bin/sh

KEEP_TAR_COUNT=10
KEEP_DIR_COUNT=5
PIMAX_LOG_DIR=/data/local/tmp/pimax_log
PIMAX_LOGCAT_PID=
#100M
FILE_SIZE_MAX=102400
AN_ROTATE_CNT_MAX=8
KL_ROTATE_CNT_MAX=2

#每次执行(开机)日志序号自增
getLogSerialNo() {
    serialNo=`getprop persist.sys.pmx.log.idx`
    if [ "$serialNo" = "" ];then
        serialNo=`expr 0`
    fi
    nextSerialNo=`expr $serialNo + 1`
    setprop persist.sys.pmx.log.idx $nextSerialNo
    echo $serialNo
}

#每次开机生成新的日志目录
generateLogDir() {
    name=$1-`date +%Y%m%d_%H%M%S`

    dir=${PIMAX_LOG_DIR}/${name}/
    mkdir -p $dir
    chmod 777 $dir
    chown system:system $dir
    echo ${name}
}

#运行抓取日志
runLogcat() {
    chmod -R 777 ${PIMAX_LOG_DIR}/$1/
    /system/bin/logcat -G 8m
    /system/bin/logcat -b all -f ${PIMAX_LOG_DIR}/$1/an.log -n ${AN_ROTATE_CNT_MAX} -r ${FILE_SIZE_MAX} &
    #/system/bin/logcat -b kernel -f ${PIMAX_LOG_DIR}/$1/kl.log -n ${KL_ROTATE_CNT_MAX} -r ${FILE_SIZE_MAX} &
    #Android 11 support -a to auto compress log
    #/system/bin/logcat -a -f ${PIMAX_LOG_DIR}/$1/all.log -r2048 -n 100 -v threadtime &
    PIMAX_LOGCAT_PID=$!
}

#处理旧的日志，进行压缩，删除等操作
processPreviousLog() {
    compressPreviousLog $1
    deletePreviousLog
}

#压缩日志进行打包
compressPreviousLog() {
    cd ${PIMAX_LOG_DIR}
    for i in `ls | grep -vE "tar.gz|$1-"`; do
        tar -czvf $i.tar.gz $i && rm -rf $i
        chmod 777 $i.tar.gz
        chown system:system $i.tar.gz
    done
}

deletePreviousLog() {
#只保留最新序列号5个
#ls *.tar.gz | egrep -v $(echo `ls *.tar.gz | sort -n -r |head -n 5`| sed 's/ /|/g')
    cd ${PIMAX_LOG_DIR}
    tarnum=`ls *.tar.gz | wc -l`
    if [ ${tarnum} -ge ${KEEP_TAR_COUNT} ];then
       delTarNum=`expr ${tarnum} - ${KEEP_TAR_COUNT}`
       delTarFiles=`ls *.tar.gz | sort -n | head -n ${delTarNum}`
       rm -rf ${delTarFiles}
    fi

    dirnum=`ls -F | grep "/$" | wc -l`
    if [ ${dirnum} -ge ${KEEP_DIR_COUNT} ];then
       delDirNum=`expr ${dirnum} - ${KEEP_DIR_COUNT}`
       delDirFiles=`ls -F | grep "/$" | sort -n | head -n ${delDirNum}`
       rm -rf ${delDirFiles}
    fi
}

#入口函数
main() {
    #set -x
    serialNo=`getLogSerialNo`
    echo "serialNo=${serialNo}"
    logDirName=`generateLogDir ${serialNo}`
    processPreviousLog ${serialNo} &
    runLogcat ${logDirName}
}

main
wait $PIMAX_LOGCAT_PID

