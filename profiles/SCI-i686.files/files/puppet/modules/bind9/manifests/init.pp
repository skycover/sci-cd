$bind9Templates="/etc/puppet/modules/bind9/templates"

class bind9 {
	package { [ 'bind9' ]: ensure => installed, allowcdrom => true } 
	file { "/etc/bind/named.conf.options":
		owner => "root",
		group => "bind",
		mode => 0640,
		content => template("$bind9Templates/int/named.conf.options.erb"),
		require => Package['bind9'],
	}
	file { "/etc/bind/named.conf.local":
		owner => "root",
		group => "bind",
		mode => 0640,
		content => template("$bind9Templates/int/named.conf.local.erb"),
		require => Package['bind9'],
	}
	file { "/etc/bind/master":
		owner => "root",
		group => "root",
		mode => 755,
		ensure => [directory, present],
		require => Package['bind9'],
	}
	file { "/etc/bind/master/$domain":
		owner => "root",
		group => "bind",
		mode => 0640,
		content => template("$bind9Templates/int/zone.erb"),
		require => [ Package['bind9'],
                             File['/etc/bind/master'],
                           ],
	}
	exec { "/usr/sbin/rndc reload":
		subscribe => File[ "/etc/bind/named.conf.options",
				   "/etc/bind/named.conf.local",
				   "/etc/bind/master/$domain"
				 ],
		refreshonly => true,
	}

}

class bind9_chroot {
	include bind9
	file { [
		"/var/lib/named",
		"/var/lib/named/dev",
		"/var/lib/named/etc",
		"/var/lib/named/var",
		"/var/lib/named/var/cache",
	       ]:
		owner => "root",
		group => "root",
		mode => 755,
		ensure => [directory, present],
	}
	file { [
		"/var/lib/named/var/cache/bind",
		"/var/lib/named/var/run",
		"/var/lib/named/var/log",
	       ]:
		owner => "bind",
		group => "bind",
		mode => 755,
		ensure => [directory, present],
		require => Package['bind9'],
	}
	file { '/etc/default/bind9':
		mode => 644, owner => root, group => root,
		source => 'puppet:///modules/bind9/bind9_chroot_default',
		require => [
			Package['bind9'],
			File["/var/lib/named"],
		],
	}
	file { '/etc/rsyslog.d/bind9_chroot':
		mode => 644, owner => root, group => root,
		source => 'puppet:///modules/bind9/bind9_chroot_rsyslog',
		require => [
			Package['bind9'],
			File["/var/lib/named/dev"],
		],
	}
	exec{'/etc/init.d/rsyslog restart':
		refreshonly => true,
		subscribe => File['/etc/rsyslog.d/bind9_chroot'],
	}
	exec {'/bin/cp -a /dev/null /var/lib/named/dev/':
		creates => "/var/lib/named/dev/null",
		require => File["/var/lib/named/dev"],
	}
	exec {'/bin/cp -a /dev/random /var/lib/named/dev/':
		creates => "/var/lib/named/dev/random",
		require => File["/var/lib/named/dev"],
	}
	file { '/usr/local/sbin/relocate-bind9-chroot':
		mode => 755, owner => root, group => root,
		source => 'puppet:///modules/bind9/relocate-bind9-chroot',
	}
	exec {"/usr/local/sbin/relocate-bind9-chroot":
		onlyif => "/usr/bin/test -d /etc/bind",
		creates => "/var/lib/named/etc/bind",
		require => [
			Package['bind9'],
			File[ "/etc/default/bind9",
                                "/var/lib/named/dev",
                                "/var/lib/named/etc",
                                "/var/lib/named/var/cache/bind",
                                "/var/lib/named/var/run",
                                "/var/lib/named/var/log" ],
		],
	}
	exec {"/bin/ln -s /var/lib/named/etc/bind /etc/bind":
		onlyif => "/usr/bin/test -d /var/lib/named/etc/bind -a ! -e /etc/bind",
	}
	file { ["/etc/localtime", "/etc/passwd"]: }
	exec {"/bin/cp /etc/localtime /var/lib/named/etc/":
		require => [
			File["/var/lib/named/etc"],
		],
		refreshonly => true,
		subscribe => File['/etc/localtime'],
	}
	exec {"/bin/egrep '^(root|bind):' /etc/passwd >/var/lib/named/etc/passwd":
		require => [
			File["/var/lib/named/etc"],
		],
		refreshonly => true,
		subscribe => File['/etc/passwd'],
	}
	
}
