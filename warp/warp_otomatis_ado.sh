#!/bin/bash

# Menonaktifkan WireGuard
#echo "2 */2 * * * root /bin/bash /root/warp_otomatis_ado.sh >> /var/log/warp_ado.log 2>&1" | tee -a /etc/crontab && \
#echo "5 */2 * * * root systemctl restart s-ui" | tee -a /etc/crontab && \
#echo "5 */2 * * * root systemctl restart x-ui" | tee -a /etc/crontab && \
#systemctl restart cron && \

wg-quick down wgcf
sleep 3
systemctl stop wg-quick@wgcf
sleep 3

# Menghapus konfigurasi dan file terkait
rm -f /etc/wireguard/wgcf.conf
rm -f /root/wgcf-account.toml
rm -f /root/wgcf-profile.conf
sleep 3

# Restart jaringan
systemctl restart networking
sleep 3

# Menjalankan skrip warp_ado.sh
bash warp_ado.sh wg4

# Menonaktifkan IPv6 dengan mengomentari baris terkait di /etc/network/interfaces
echo "Mengomentari IPv6 di /etc/network/interfaces..."
cp /etc/network/interfaces /etc/network/interfaces.bak_$(date +%Y%m%d%H%M%S)
sleep 3
sed -i '/iface .* inet6 /,/^$/ { /^\s*#/! s/^/# / }' /etc/network/interfaces

echo "Restart jaringan untuk menerapkan perubahan..."
systemctl restart networking

# Menonaktifkan IPv6 melalui sysctl.conf
echo "Menonaktifkan IPv6 di sysctl.conf..."
if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
else
    echo "Pengaturan IPv6 sudah ada di sysctl.conf."
fi

# Menambahkan pengaturan IPv6 ke /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf

# Menghapus ipv6.conf jika ada
if [ -f "/etc/sysctl.d/ipv6.conf" ]; then
    rm -f /etc/sysctl.d/ipv6.conf
    echo "/etc/sysctl.d/ipv6.conf telah dihapus."
else
    echo "File ipv6.conf tidak ditemukan."
fi

# Menerapkan perubahan sysctl
sysctl -p

# Memverifikasi apakah IPv6 telah dinonaktifkan
echo "Memverifikasi apakah IPv6 telah dinonaktifkan..."
ip a | grep inet6

echo -e "Selesai! IPv6 berhasil dinonaktifkan. \n"

# Menampilkan isi /etc/network/interfaces
echo "Menampilkan /etc/network/interfaces..."
cat /etc/network/interfaces

# Mengecek status jaringan
systemctl status networking

# Mengecek koneksi jaringan
lsattr /etc/network/

systemctl restart s-ui
systemctl restart x-ui
