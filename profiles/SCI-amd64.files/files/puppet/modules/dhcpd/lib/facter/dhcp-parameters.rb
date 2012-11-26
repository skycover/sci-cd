Facter.add("sci_dhcp_subnet") do
        setcode do
                %x{if (ip addr show eth1 > /dev/null) then ipcalc `ip addr show eth1|grep inet\ |cut -f6 -d' '`|grep Network|cut -f4 -d' '|cut -f1 -d'/'; else ipcalc `ip addr show eth0|grep inet\ |cut -f6 -d' '`|grep Network|cut -f4 -d' '|cut -f1 -d'/'; fi}.chomp
        end
end

Facter.add("sci_dhcp_netmask") do
        setcode do
                %x{if (ip addr show eth1 > /dev/null) then ipcalc `ip addr show eth1|grep inet\ |cut -f6 -d' '`|grep Netmask|cut -f4 -d' '; else ipcalc `ip addr show eth0|grep inet\ |cut -f6 -d' '`|grep Netmask|cut -f4 -d' '; fi}.chomp
        end
end

Facter.add("sci_dhcp_hostmin") do
        setcode do
                %x{if (ip addr show eth1 > /dev/null) then ipcalc `ip addr show eth1|grep inet\ |cut -f6 -d' '`|grep HostMin|cut -f4 -d' '|awk -F. '{print $1"."$2"."$3"."$4+10}'; else ipcalc `ip addr show eth0|grep inet\ |cut -f6 -d' '`|grep HostMin|cut -f4 -d' '|awk -F. '{print $1"."$2"."$3"."$4+10}'; fi}.chomp
        end
end

Facter.add("sci_dhcp_hostmax") do
        setcode do
                %x{if (ip addr show eth1 > /dev/null) then ipcalc `ip addr show eth1|grep inet\ |cut -f6 -d' '`|grep HostMax|cut -f4 -d' '; else ipcalc `ip addr show eth0|grep inet\ |cut -f6 -d' '`|grep HostMax|cut -f4 -d' '|awk -F. '{print $1"."$2"."$3"."$4-5}'; fi}.chomp
        end
end

Facter.add("sci_dhcp_ipaddress") do
        setcode do
                %x{if (ip addr show eth1 > /dev/null) then ip -4 addr show eth1|grep inet\ |cut -f6 -d' '|cut -f1 -d'/'; else ip -4 addr show eth0|grep inet\ |cut -f6 -d' '|cut -f1 -d'/'; fi}.chomp end
end

Facter.add("sci_dnskey") do
        setcode do
                %x{cat /etc/bind/keys|grep secret|awk '{print $2}'}.chomp
        end
end

