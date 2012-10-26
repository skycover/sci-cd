class dhcpd(enabled=yes) {
if $enabled==yes {
	package {isc-dhcp-server: ensure=> installed}

        file { "/etc/dhcp/dhcpd.conf.puppet":
                owner => "root",
                group => "root",
                mode => 600,
                content => template("dhcpd/dhcpd.conf.erb"),
                require => [ Package['isc-dhcp-server'] ],
		
        }

	
        exec { "/bin/cp -a /etc/dhcp/dhcpd.conf.puppet /etc/dhcp/dhcpd.conf":
                unless  => "/usr/bin/test -e /etc/dhcp/dhcpd.conf",
                require => [ Package['isc-dhcp-server'] ],
        }


        exec { "/etc/init.d/isc-dhcp-server restart":
                subscribe => File[ "/etc/dhcp/dhcpd.conf.puppet" ],
                require => [ Package['isc-dhcp-server'] ],
                refreshonly => true,
        }
}
else {
	package {isc-dhcp-server: ensure=> purged}
}
}
