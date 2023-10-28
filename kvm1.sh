#!/bash/bin

initialize(){
yum install qemu-kvm qemu-img libvirt
yum install virt-install libvirt-python virt-manager libvirt-client
systemctl restart libvirtd
virt-install --name=centos7u7-template --nographics --memory=2048,maxmemory=4096 --vcpus=1,maxvcpus=4 --disk path=/var/lib/libvirt/images/centos7u7-template.img,size=10,format=qcow2,bus=virtio --network bridge=virbr0,model=virtio --location=http://192.168.10.100/iso --extra-args="ks=http://192.168.10.100/ks/ks.cfg console=ttyS0"
}



create-vm(){
virsh list --all
cat << EOF
######################################
1.克隆单个虚拟机
2.克隆一组虚拟机
3.退出
######################################
EOF
read -p "请选择您的操作:[1|2|3]:" num
case $num in
	1)
	read -p "请输入主机名:" hostname
	qemu-img create -f qcow2 -b  /var/lib/libvirt/images/centos7u7-template.img /var/lib/libvirt/images/${hostname}.img
	cp /etc/libvirt/qemu/centos7u7-template.xml /etc/libvirt/qemu/${hostname}.xml
	sed -i s/centos7u7-template/$hostname/ /etc/libvirt/qemu/${hostname}.xml
	sed -i /uuid/d /etc/libvirt/qemu/${hostname}.xml
	sed -i /mac address/d /etc/libvirt/qemu/${hostname}.xml
	virsh define /etc/libvirt/qemu/${hostname}.xml	
	;;
	2)
	read -p "请输入克隆虚拟机名[不能重复]:" hostname
	read -p "请输入克隆数量:" num
	read -p "请输入克隆虚拟机起始地址[范围100-200]默认[100]:" ip
	if [ -z $ip ]
	then 
		ip=100
	fi
	for (( i=1;i<=num;i++ ))
	do
		qemu-img create -f qcow2 -b  /var/lib/libvirt/images/centos7u7-template.img /var/lib/libvirt/images/${hostname}-${i}.img
	        cp /etc/libvirt/qemu/centos7u7-template.xml /etc/libvirt/qemu/${hostname}-${i}.xml
        	sed -i "s/centos7u7-template/${hostname}-${i}/" /etc/libvirt/qemu/${hostname}-${i}.xml
        	sed -i "/uuid/d"  /etc/libvirt/qemu/${hostname}-${i}.xml
       		sed -i "/mac address/d"  /etc/libvirt/qemu/${hostname}-${i}.xml
		#修改虚拟配置
		guestmount -a /var/lib/libvirt/images/${hostname}-${i}.img -i /mnt/
		sed -i "/HWADDR/d" /mnt/etc/sysconfig/network-scripts/ifcfg-eth0
		sed -i "s/192.168.122.100/192.168.122.$ip/" /mnt/etc/sysconfig/network-scripts/ifcfg-eth0 
		echo "ifup eth0" >> /mnt/etc/rc.local
		chmod a+x /mnt/etc/rc.local
		echo "${hostname}-${ip}.com" > /mnt/etc/hostname
		echo "192.168.122.${ip} ${hostname}-${ip}.com" >> /mnt/etc/hosts
		umount /mnt/
		virsh define /etc/libvirt/qemu/${hostname}-${i}.xml
		ip=$((ip+1))
	done
	;;
	3)
	break
	;;
esac
}

start-vm(){
virsh list --all
cat << EOF
########################################
1.启动单个虚拟机
2.启动一组虚拟机
3.退出
########################################
EOF
read -p "请选择您的操作:[1|2|3]:" num
case $num in
	1)	
	read -p "请输入要启动单个的虚拟机名称:" name
	virsh start $name		
	;;
	2)
	read -p "请输入要启动的虚拟机名称:" name
	num=$(virsh list --all | grep -c $name)
	for ((i=1;i<=$num;i++))
	do
		virsh start $name-$i
	done
	;;
	3)
	break
	;;
esac

}

stop-vm(){
virsh list --all
cat << EOF
########################################
1.停止单个虚拟机
2.停止一组虚拟机
3.退出
########################################
EOF
read -p "请选择您的操作:[1|2|3]:" num
case $num in
        1)
	read -p "请输入要停止单个的虚拟机名称:" name
	virsh destroy $name &>/dev/null
        ;;      
        2)
        read -p "请输入要停止的虚拟机名称:" name
	num=$(virsh list  | grep -c $name)
	for ((i=1;i<=$num;i++))
	do
		virsh destroy $name-$i
	done
	;;
        3)
        break
        ;;
esac
}

delect-vm(){
virsh list --all
cat << EOF
########################################
1.删除单个虚拟机
2.删除一组虚拟机
3.退出
########################################
EOF
read -p "请选择您的操作:[1|2|3]:" num
case $num in
        1)
 	read -p "请输入要删除单个的虚拟机名称:" name
	virsh destory $name &>/dev/null
	virsh undefine $name
	rm -rf /etc/libvirt/qemu/${name}.xml
	rm -rf /var/lib/libvirt/images/${name}.img
       	;;      
        2)
	read -p "请输入要删除的虚拟机名称:" name
	num=$(virsh list --all | grep -c $name)
	for (( i=1;i<=$num;i++ ))
	do
		virsh destory $name-$i &>/dev/null
		virsh undefine $name-$i
		rm -rf /etc/libvirt/qemu/${name}-${i}.xml
		rm -rf /var/lib/libvirt/images/${name}-${i}.img
	done
        ;;
        3)
        break
        ;;
esac
}

guestfish(){
cat << EOF
#####################################
1.添加磁盘
2.删除磁盘
3.退出
#####################################
EOF
read -p "请选择您的操作:[1|2|3]:" num
case $num in
	1)
	qemu-img create -f qcow2 /var/lib/libvirt/images/disk01.img 2G
	read -p "添加磁盘虚拟机名称:" name
	virsh attach-disk $name --source /var/lib/libvirt/images/disk01.img --target vdb --cache writeback --subdriver qcow2 --persistent
	;;
	2)
	read -p "移除磁盘虚拟机名称:" name
	virsh detach-disk $name vdb --persistent	
	;;
	3)
	;;
esac
}

interface(){
cat << EOF
#####################################
1.添加网卡
2.删除网卡
3.退出
#####################################
EOF
read -p "请选择您的操作:[1|2|3]:" num
case $num in
	1)
	read -p "添加网卡虚拟机名称:" name
	virsh attach-interface $name --type bridge --source virbr0 --persistent
	;;
	2)
	read -p "移除网卡虚拟机名称:" name
	virsh domiflist $name
	read -p "请输入接口名字:" net
	mac_in=`virsh domiflist $vm_name  | grep $net | awk '{print $5}'`
	virsh detach-interface $vm_name network $mac_in --persistent
	;;
	3)
	exit
	;;
esac
}

while :
do
cat << EOF
####################################################
1.初始化系统
2.查询虚拟机
3.克隆虚拟机
4.启动虚拟机
5.停止虚拟机
6.删除虚拟机
7.添加删除磁盘
8.添加删除网卡
9.退出脚本
####################################################
EOF

read -p "请选择您的操作:[1|2|3|4|5|6|7|8|9]:" num
case $num in 
	1)
	initialize
	;;
	2)
	virsh list --all
	;;
	3)
	create-vm
	;;
	4)
	while :
	do
		start-vm
	done
	;;
	5)
	while :
	do
	stop-vm
	done
	;;
	6)
	while :
	do
	delect-vm
	done
	;;
	7)
	guestfish		
	;;
	8)
	interface	
	;;
	9)
	exit
	;;
esac
done
