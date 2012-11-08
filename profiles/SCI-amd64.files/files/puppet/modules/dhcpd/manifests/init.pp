class dhcpd(enabled=yes) {
if $enabled==yes {
        package {isc-dhcp-server: ensure=> installed}
}
else {
        package {isc-dhcp-server: ensure=> removed}
}

        file { "/etc/dhcp/dhcpd.conf.puppet":
                owner => "root",
                group => "root",
                mode => 600,
                content => template("dhcpd/dhcpd.conf.erb"),
                require => Package['isc-dhcp-server'],

        }


        exec { "/bin/cp -a /etc/dhcp/dhcpd.conf.puppet /etc/dhcp/dhcpd.conf; touch /etc/dhcp/.disable-puppet":
                require => Package['isc-dhcp-server'],
				creates =>  "/etc/dhcp/.disable-puppet",
        }


        exec { "/etc/init.d/isc-dhcp-server restart":
                subscribe => File[ "/etc/dhcp/dhcpd.conf.puppet" ],
                refreshonly => true,
                require => Package['isc-dhcp-server'],
        }
}
