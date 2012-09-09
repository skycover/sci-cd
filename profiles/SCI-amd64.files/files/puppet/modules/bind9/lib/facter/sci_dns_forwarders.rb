Facter.add("sci_dns_forwarders") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $DNS_FORWARDERS}.chomp
	end
end
