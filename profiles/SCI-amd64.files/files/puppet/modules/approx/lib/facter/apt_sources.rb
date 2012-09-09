Facter.add("sci_apt_debian") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $APT_DEBIAN}.chomp
	end
end
Facter.add("sci_apt_security") do
	setcode do
		%x{. /etc/sci/sci.conf; echo $APT_SECURITY}.chomp
	end
end
