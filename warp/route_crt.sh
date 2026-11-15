#!/bin/bash

# Nama file log
log_filename="log-exclude-warp-$(date +'%Y-%m-%d-%H-%M-%S-%A').txt"

# Cek apakah user menjalankan skrip sebagai root
if [ "$EUID" -ne 0 ]; then
    echo "Silakan jalankan skrip ini dengan hak akses root." | tee -a "$log_filename"
    exit 1
fi

# Periksa apakah domain diberikan sebagai argumen
if [ "$#" -lt 1 ]; then
    echo "Penggunaan: $0 <subdomain1> [subdomain2] ... [subdomainN]" | tee -a "$log_filename"
    exit 1
fi

# Fungsi untuk mendapatkan domain utama dari subdomain
get_main_domain() {
    local subdomain=$1
    echo "$subdomain" | awk -F. '{print $(NF-1)"."$NF}'
}

# Fungsi untuk mengambil dan menampilkan IP (IPv4 dan IPv6) untuk satu domain
process_domain() {
    SUBDOMAIN=$1
    DOMAIN_MAIN=$(get_main_domain "$SUBDOMAIN")

    # Menampilkan domain utama
    echo "Domain utama: $DOMAIN_MAIN" | tee -a "$log_filename"

    # Jalankan dig untuk subdomain yang diinputkan
    echo "Mengambil informasi DNS untuk $SUBDOMAIN..." | tee -a "$log_filename"
    dig ANY "$SUBDOMAIN" +noall +answer | tee -a "$log_filename"
    echo "" | tee -a "$log_filename"

    # Mengambil subdomain menggunakan crt.sh
    echo "Mengambil subdomain untuk domain: $DOMAIN_MAIN" | tee -a "$log_filename"
    response=$(curl -s "https://crt.sh/?q=%.$DOMAIN_MAIN&output=json")
    subdomains=$(echo "$response" | jq -r '.[].name_value' | awk -v domain="$DOMAIN_MAIN" '{if ($0 ~ "\\." domain "$") print $0}' | sort -u)

    # Tambahkan domain utama ke daftar subdomain
    subdomains="$subdomains
$DOMAIN_MAIN"

    echo "Subdomain ditemukan:" | tee -a "$log_filename"
    echo "$subdomains" | tee -a "$log_filename"

    # Mengambil IP dari subdomain dan domain utama
    echo "Mendapatkan alamat IP untuk subdomain dan domain utama..." | tee -a "$log_filename"
    ipv4_ips=$(for subdomain in $subdomains; do
        dig +short A "$subdomain" 2>>"$log_filename"
    done | sort -u)

    # Tampilkan domain dan alamat IPv4 yang ditemukan
    echo "Domain dan alamat IPv4 yang ditemukan:" | tee -a "$log_filename"
    for subdomain in $subdomains; do
        ips=$(dig +short A "$subdomain" 2>>"$log_filename")
        if [ -n "$ips" ]; then
            echo "$subdomain:" | tee -a "$log_filename"
            echo "$ips" | tee -a "$log_filename"
            echo "" | tee -a "$log_filename"
        fi
    done

    # Dapatkan IPv6 dari Python
    get_ipv6_from_python() {
        local domain=$1
        python3 - <<EOF
import dns.resolver

def get_ipv6_addresses(domain):
    try:
        answers = dns.resolver.resolve(domain, 'AAAA')
        ipv6_addresses = [answer.to_text() for answer in answers]
        return ipv6_addresses
    except (dns.resolver.NoAnswer, dns.resolver.NXDOMAIN):
        return []

ipv6_addresses = get_ipv6_addresses("$domain")
if ipv6_addresses:
    for ipv6 in ipv6_addresses:
        print(ipv6)
EOF
    }

    # Dapatkan IPv6 untuk domain utama dan subdomain
    ipv6_ips=$(for subdomain in $subdomains; do
        get_ipv6_from_python "$subdomain"
    done | sort -u)

    # Tampilkan domain dan alamat IPv6 yang ditemukan
    echo "Domain dan alamat IPv6 yang ditemukan:" | tee -a "$log_filename"
    for subdomain in $subdomains; do
        ips=$(get_ipv6_from_python "$subdomain")
        if [ -n "$ips" ]; then
            echo "$subdomain:" | tee -a "$log_filename"
            echo "$ips" | tee -a "$log_filename"
            echo "" | tee -a "$log_filename"
        fi
    done

    # Mendapatkan IP, Gateway, dan Interface IPv4
    IPV4_GATEWAY=$(ip -4 route | grep default | awk '{print $3}')
    IPV4_INTERFACE=$(ip -4 route | grep default | awk '{print $5}')

    if [ -n "$IPV4_GATEWAY" ] && [ -n "$IPV4_INTERFACE" ]; then
        echo "Menambahkan aturan routing untuk IPv4" | tee -a "$log_filename"
        for IP in $ipv4_ips; do
            if [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                ip -4 route add "$IP"/32 via "$IPV4_GATEWAY" dev "$IPV4_INTERFACE" 2>>"$log_filename"
                if [ $? -eq 0 ]; then
                    echo "Aturan routing IPv4 berhasil ditambahkan untuk $IP." | tee -a "$log_filename"
                else
                    echo "Gagal menambahkan aturan routing IPv4 untuk $IP atau aturan sudah ada." | tee -a "$log_filename"
                fi
            fi
        done
    else
        echo "Tidak ada konfigurasi IPv4 yang ditemukan." | tee -a "$log_filename"
    fi

    # Mendapatkan IP, Gateway, dan Interface IPv6
    IPV6_GATEWAY=$(ip -6 route | grep default | awk '{print $3}')
    IPV6_INTERFACE=$(ip -6 route | grep default | awk '{print $5}')

    if [ -n "$IPV6_GATEWAY" ] && [ -n "$IPV6_INTERFACE" ]; then
        echo "Menambahkan aturan routing untuk IPv6" | tee -a "$log_filename"
        for IP in $ipv6_ips; do
            if [[ $IP =~ ^[0-9a-fA-F:]+$ ]]; then
                ip -6 route add "$IP"/128 via "$IPV6_GATEWAY" dev "$IPV6_INTERFACE" 2>>"$log_filename"
                if [ $? -eq 0 ]; then
                    echo "Aturan routing IPv6 berhasil ditambahkan untuk $IP." | tee -a "$log_filename"
                else
                    echo "Gagal menambahkan aturan routing IPv6 untuk $IP atau aturan sudah ada." | tee -a "$log_filename"
                fi
            fi
        done
    else
        echo "Tidak ada konfigurasi IPv6 yang ditemukan." | tee -a "$log_filename"
    fi
}

# Loop melalui semua domain yang diberikan sebagai argumen
for SUBDOMAIN in "$@"; do
    process_domain "$SUBDOMAIN"
done

# Verifikasi aturan routing
echo "Verifikasi aturan routing IPv4:" | tee -a "$log_filename"
ip route show | tee -a "$log_filename"

echo "Verifikasi aturan routing IPv6:" | tee -a "$log_filename"
ip -6 route show | tee -a "$log_filename"

exit 0
