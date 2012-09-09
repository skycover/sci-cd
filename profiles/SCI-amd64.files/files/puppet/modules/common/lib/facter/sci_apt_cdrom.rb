Facter.add("sci_apt_cdrom") do
	setcode do
		%x{/bin/grep "^deb cdrom" /etc/apt/sources.list}.chomp
	end
end
