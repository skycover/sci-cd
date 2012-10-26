Facter.add("sci_subnet") do
        setcode do
                %x{. /etc/sci/sci.conf; echo $CLUSTER_IP|awk -F. '{print $1"."$2"."$3}'}.chomp
        end
end

Facter.add("sci_dnskey") do
        setcode do
                %x{cat /etc/bind/keys|grep secret|awk '{print $2}'}.chomp
        end
end

