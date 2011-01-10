define install_service($source) {
	file { "/etc/init.d/$name":
		mode => 755, owner => root, group => root,
		source => "puppet:///$source"
	}
	exec { "update-rc.d $name defaults":
		path => '/usr/bin:/usr/sbin:/bin:/sbin',
		subscribe => File["/etc/init.d/$name"],
		refreshonly => true
	}
}

define check_alternatives($linkto, $package) {
	exec { "/usr/sbin/update-alternatives --set $name $linkto":
		unless => "/bin/sh -c '[ -L /etc/alternatives/$name ] && [ /etc/alternatives/$name -ef $linkto ]'",
		require => Package[$package],
	}
}
