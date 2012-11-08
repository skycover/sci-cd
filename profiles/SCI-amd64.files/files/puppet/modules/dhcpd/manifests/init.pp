class dhcpd($enabled=yes) {
if $enabled==yes {
        package {isc-dhcp-server: ensure=> installed}
}
else {
        exec { "/usr/bin/apt-get -q -y -o DPkg::Options::=--force-confold --force-yes install isc-dhcp-server":
                creates => "/etc/dhcp/dhcpd.conf",
        }

        package {isc-dhcp-server:
                ensure=> absent,
                require => Exec [ "/usr/bin/apt-get -q -y -o DPkg::Options::=--force-confold --force-yes install isc-dhcp-server" ],
        }
}

        file { "/etc/dhcp/dhcpd.conf.puppet":
                owner => "root",
                group => "root",
                mode => 600,
                content => template("dhcpd/dhcpd.conf.erb"),
                require => Package['isc-dhcp-server'],

        }


        exec { '/bin/cp -a /etc/dhcp/dhcpd.conf.puppet /etc/dhcp/dhcpd.conf; /bin/sed -i "s/changeme/$(/bin/cat /etc/bind/keys|/bin/grep secret|/usr/bin/cut -f6 -d\' \')/" /etc/dhcp/dhcpd.conf; touch /etc/dhcp/.disable-puppet':
                require => Package['isc-dhcp-server'],
                creates =>  "/etc/dhcp/.disable-puppet",
        }


        exec { "/etc/init.d/isc-dhcp-server restart":
                subscribe => File[ "/etc/dhcp/dhcpd.conf.puppet" ],
                refreshonly => true,
                require => Package['isc-dhcp-server'],
        }
}
