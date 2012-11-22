class dhcpd($enabled=yes) {

        file { "/etc/dhcp/dhcpd.conf.puppet":
                owner => "root",
                group => "root",
                mode => 600,
                content => template("dhcpd/dhcpd.conf.erb"),
        }

        file { "/etc/dhcp/dhcpd.conf": }

        exec { '/usr/sbin/dpkg-divert --divert /etc/dhcp/dhcpd.conf.dist --rename /etc/dhcp/dhcpd.conf; /bin/cp -a /etc/dhcp/dhcpd.conf.puppet /etc/dhcp/dhcpd.conf; /bin/sed -i "s/changeme/$(/bin/cat /etc/bind/keys|/bin/grep secret|/usr/bin/cut -f6 -d\' \')/" /etc/dhcp/dhcpd.conf':
                require =>  File[ "/etc/dhcp/dhcpd.conf.puppet" ],
                creates =>  [ "/etc/dhcp/dhcpd.conf", ],
        }

if $enabled==yes {
        package {isc-dhcp-server:
                ensure=> installed,
        }

        File [ '/etc/dhcp/dhcpd.conf' ] -> Package [ 'isc-dhcp-server' ]

        exec { "/etc/init.d/isc-dhcp-server restart":
                subscribe => File[ "/etc/dhcp/dhcpd.conf" ],
                refreshonly => true,
                require => Package['isc-dhcp-server'],
        }
}
else {
        package {isc-dhcp-server:
                ensure=> absent,
        }
}

}
