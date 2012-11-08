Facter.add("sci_cluster_name") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $CLUSTER_NAME}.chomp
	end
end
Facter.add("sci_cluster_ip") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $CLUSTER_IP}.chomp
	end
end
Facter.add("sci_cluster_revip") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $CLUSTER_IP|awk -F. '{print $4"."$3"."$2"."$1}'}.chomp
	end
end
Facter.add("sci_node1_name") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $NODE1_NAME}.chomp
	end
end
Facter.add("sci_node1_ip") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $NODE1_IP}.chomp
	end
end
Facter.add("sci_node1_revip") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $NODE1_IP|awk -F. '{print $4"."$3"."$2"."$1}'}.chomp
	end
end
Facter.add("sci_node1_san_ip") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $NODE1_SAN_IP}.chomp
	end
end
Facter.add("sci_node1_san_revip") do
        setcode do
                %x{. /etc/sci/sci.conf; if [ -n "$NODE1_SAN_IP" ]; then echo $NODE1_SAN_IP|awk -F. '{print $4"."$3"."$2"."$1}';fi}.chomp
        end
end
Facter.add("sci_node1_lan_ip") do
        setcode do
                %x{. /etc/sci/sci.conf; echo $NODE1_LAN_IP}.chomp
        end
end
Facter.add("sci_node1_lan_revip") do
        setcode do
                %x{. /etc/sci/sci.conf; if [ -n "$NODE1_LAN_IP" ]; then echo $NODE1_LAN_IP|awk -F. '{print $4"."$3"."$2"."$1}';fi}.chomp
        end
end
Facter.add("sci_node2_name") do
        setcode do
                %x{. /etc/sci/sci.conf; echo $NODE2_NAME}.chomp
        end
end
Facter.add("sci_node2_ip") do
        setcode do
                %x{. /etc/sci/sci.conf; echo $NODE2_IP}.chomp
        end
end
Facter.add("sci_node2_revip") do
        setcode do
                %x{. /etc/sci/sci.conf; if [ -n "$NODE2_IP" ] ;then echo $NODE2_IP|awk -F. '{print $4"."$3"."$2"."$1}';fi}.chomp
        end
end
Facter.add("sci_node2_san_ip") do
        setcode do
                %x{. /etc/sci/sci.conf; echo $NODE2_SAN_IP}.chomp
        end
end
Facter.add("sci_node2_san_revip") do
        setcode do
                %x{. /etc/sci/sci.conf; if [ -n "$NODE2_SAN_IP" ] ;then echo $NODE2_SAN_IP|awk -F. '{print $4"."$3"."$2"."$1}';fi}.chomp
        end
end
Facter.add("sci_node2_lan_ip") do
        setcode do
                %x{. /etc/sci/sci.conf; echo $NODE2_LAN_IP}.chomp
        end
end
Facter.add("sci_node2_lan_revip") do
        setcode do
                %x{. /etc/sci/sci.conf; if [ -n "$NODE2_LAN_IP" ] ;then echo $NODE2_LAN_IP|awk -F. '{print $4"."$3"."$2"."$1}';fi}.chomp
        end
end
Facter.add("sci_sci_revip") do
        setcode do
                %x{host sci|awk '{print $4}'|awk -F. '{print $4"."$3"."$2"."$1}'}.chomp
        end
end
